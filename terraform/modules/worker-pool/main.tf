###############################################################################
# worker-pool module - Launch Template + Auto Scaling Group
#
# This is the heart of the campaign-burst autoscaling:
#   - Launch Template defines HOW a worker is built (AMI, type, user-data).
#   - ASG defines HOW MANY (min/max). Cluster Autoscaler adjusts desired
#     between those bounds based on pending pods.
#   - New nodes auto-join the cluster via user-data (reads join cmd from SSM).
#
# The ASG tags are what the Cluster Autoscaler looks for to discover this group.
###############################################################################

locals {
  common_tags = merge(var.tags, { Name = "${var.name}-worker" })

  user_data = base64encode(templatefile("${path.module}/user-data.sh.tmpl", {
    cluster_name        = var.cluster_name
    region              = var.region
    ssm_join_param_name = var.ssm_join_param_name
    k8s_version         = var.k8s_version
  }))
}

# --- Launch Template (the "how to build a worker" recipe) -------------------
resource "aws_launch_template" "worker" {
  name_prefix   = "${var.name}-worker-"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name
  user_data     = local.user_data

  iam_instance_profile {
    name = aws_iam_instance_profile.worker.name
  }

  vpc_security_group_ids = [var.security_group_id]

  metadata_options {
    http_tokens   = "required" # IMDSv2 only
    http_endpoint = "enabled"
  }

  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size = var.root_volume_size
      volume_type = "gp3"
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(local.common_tags, {
      "kubernetes.io/cluster/${var.cluster_name}" = "owned"
      "k8s-role"                                  = "worker"
    })
  }

  lifecycle {
    create_before_destroy = true
  }
}

# --- Auto Scaling Group (the "how many" + autoscaling bounds) ---------------
resource "aws_autoscaling_group" "worker" {
  name                = "${var.name}-worker-asg"
  vpc_zone_identifier = var.subnet_ids
  min_size            = var.min_size
  max_size            = var.max_size
  desired_capacity    = var.desired_capacity
  health_check_type   = "EC2"

  launch_template {
    id      = aws_launch_template.worker.id
    version = "$Latest"
  }

  # Name tag for the instances.
  tag {
    key                 = "Name"
    value               = "${var.name}-worker"
    propagate_at_launch = true
  }

  # Kubernetes ownership tag.
  tag {
    key                 = "kubernetes.io/cluster/${var.cluster_name}"
    value               = "owned"
    propagate_at_launch = true
  }

  # --- Cluster Autoscaler discovery tags ---
  # The autoscaler scans for ASGs carrying these two tags.
  tag {
    key                 = "k8s.io/cluster-autoscaler/enabled"
    value               = "true"
    propagate_at_launch = false
  }

  tag {
    key                 = "k8s.io/cluster-autoscaler/${var.cluster_name}"
    value               = "owned"
    propagate_at_launch = false
  }

  # Cluster Autoscaler owns desired_capacity at runtime - don't let Terraform
  # fight it on every apply.
  lifecycle {
    ignore_changes = [desired_capacity]
  }
}
