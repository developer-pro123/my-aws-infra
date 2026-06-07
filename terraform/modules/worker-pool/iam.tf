###############################################################################
# worker-pool module - IAM for worker nodes
#
# Workers only need to READ the kubeadm join command from SSM so they can
# auto-join the cluster on boot. (The Cluster Autoscaler runs on the control
# plane, so workers do NOT need autoscaling permissions.)
###############################################################################

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "worker" {
  name               = "${var.name}-worker-role"
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = merge(var.tags, { Name = "${var.name}-worker-role" })
}

data "aws_iam_policy_document" "worker" {
  statement {
    sid       = "ReadJoinCommand"
    actions   = ["ssm:GetParameter"]
    resources = [var.ssm_join_param_arn]
  }
}

resource "aws_iam_role_policy" "worker" {
  name   = "${var.name}-worker-policy"
  role   = aws_iam_role.worker.id
  policy = data.aws_iam_policy_document.worker.json
}

resource "aws_iam_instance_profile" "worker" {
  name = "${var.name}-worker-profile"
  role = aws_iam_role.worker.name
}
