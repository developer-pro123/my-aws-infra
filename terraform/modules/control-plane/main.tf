###############################################################################
# control-plane module - the single Kubernetes master node
#
# Creates:
#   IAM role + instance profile  (write join command to SSM + run Cluster Autoscaler)
#   aws_instance                 the master (in a public subnet)
#   aws_eip                      stable public IP for kubectl/SSH
#   local_file                   generated Ansible inventory (masters group)
#
# NOTE: the Cluster Autoscaler runs as a pod ON the control plane, so the
# control plane's instance role carries the autoscaling permissions.
###############################################################################

locals {
  common_tags = merge(var.tags, { Name = "${var.name}-control-plane" })

  # When acting as a NAT instance: enable IP forwarding + masquerade outbound.
  # Runs at boot via cloud-init so private workers have internet before they
  # even start (they need it to install packages and read SSM).
  nat_user_data = <<-EOT
    #!/bin/bash
    set -e
    echo 'net.ipv4.ip_forward=1' > /etc/sysctl.d/99-nat.conf
    sysctl -p /etc/sysctl.d/99-nat.conf
    IFACE=$(ip route | awk '/default/ {print $5; exit}')
    iptables -t nat -A POSTROUTING -o "$IFACE" -j MASQUERADE
    # Persist the rule across reboots.
    DEBIAN_FRONTEND=noninteractive apt-get update -y
    DEBIAN_FRONTEND=noninteractive apt-get install -y iptables-persistent
    netfilter-persistent save
  EOT
}

# --- IAM: assume-role for EC2 ------------------------------------------------
data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "control_plane" {
  name               = "${var.name}-control-plane-role"
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = local.common_tags
}

# Permission set: write join command to SSM + Cluster Autoscaler actions
data "aws_iam_policy_document" "control_plane" {
  # Master writes the kubeadm join command here for workers to read.
  statement {
    sid       = "WriteJoinCommand"
    actions   = ["ssm:PutParameter", "ssm:GetParameter"]
    resources = [var.ssm_join_param_arn]
  }

  # Cluster Autoscaler: discover and scale the worker ASG.
  statement {
    sid = "ClusterAutoscaler"
    actions = [
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeAutoScalingInstances",
      "autoscaling:DescribeLaunchConfigurations",
      "autoscaling:DescribeScalingActivities",
      "autoscaling:DescribeTags",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeLaunchTemplateVersions",
      "ec2:DescribeImages",
    ]
    resources = ["*"]
  }

  statement {
    sid = "ClusterAutoscalerWrite"
    actions = [
      "autoscaling:SetDesiredCapacity",
      "autoscaling:TerminateInstanceInAutoScalingGroup",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "control_plane" {
  name   = "${var.name}-control-plane-policy"
  role   = aws_iam_role.control_plane.id
  policy = data.aws_iam_policy_document.control_plane.json
}

resource "aws_iam_instance_profile" "control_plane" {
  name = "${var.name}-control-plane-profile"
  role = aws_iam_role.control_plane.name
}

# --- The control plane EC2 instance -----------------------------------------
resource "aws_instance" "control_plane" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [var.security_group_id]
  key_name                    = var.key_name
  iam_instance_profile        = aws_iam_instance_profile.control_plane.name
  associate_public_ip_address = true

  # When acting as a NAT instance it must forward traffic that isn't addressed
  # to itself, so the source/destination check has to be turned off.
  source_dest_check = var.act_as_nat ? false : true

  # NAT setup script (only when act_as_nat = true).
  user_data = var.act_as_nat ? local.nat_user_data : null

  metadata_options {
    http_tokens                 = "required" # IMDSv2 only
    http_put_response_hop_limit = 2          # let pods (cluster-autoscaler) reach IMDS for the node IAM role
  }

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp3"
  }

  tags = merge(local.common_tags, {
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    "k8s-role"                                  = "control-plane"
  })
}

# --- Stable public IP --------------------------------------------------------
resource "aws_eip" "control_plane" {
  instance = aws_instance.control_plane.id
  domain   = "vpc"
  tags     = merge(local.common_tags, { Name = "${var.name}-control-plane-eip" })
}

# --- Default route for private subnets through this node (NAT instance) ------
# Only created when act_as_nat = true (dev). Points each private route table's
# 0.0.0.0/0 at the control-plane's network interface instead of a NAT gateway.
resource "aws_route" "private_via_control_plane" {
  count                  = var.act_as_nat ? length(var.private_route_table_ids) : 0
  route_table_id         = var.private_route_table_ids[count.index]
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_instance.control_plane.primary_network_interface_id
}

# --- Generate the Ansible inventory -----------------------------------------
resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/templates/inventory.tmpl", {
    control_plane_ip     = aws_eip.control_plane.public_ip
    ssh_user             = var.ssh_user
    ssh_private_key_path = var.ssh_private_key_path
  })
  filename = var.ansible_inventory_path
}
