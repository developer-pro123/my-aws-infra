###############################################################################
# security module - security groups for a self-managed kubeadm cluster
#
# Two SGs:
#   control_plane  - the master node (API server, etcd, scheduler...)
#   worker         - the ASG worker nodes (kubelet, pods, NodePorts)
#
# Cross-references between the two SGs use standalone aws_security_group_rule
# resources (not inline rules) to avoid a dependency cycle.
###############################################################################

locals {
  common_tags = merge(var.tags, { Name = var.name })
}

# --- Security groups ---------------------------------------------------------
resource "aws_security_group" "control_plane" {
  name        = "${var.name}-control-plane-sg"
  description = "Kubernetes control plane (master) node"
  vpc_id      = var.vpc_id
  tags        = merge(local.common_tags, { Name = "${var.name}-control-plane-sg" })
}

resource "aws_security_group" "worker" {
  name        = "${var.name}-worker-sg"
  description = "Kubernetes worker nodes (ASG)"
  vpc_id      = var.vpc_id
  tags        = merge(local.common_tags, { Name = "${var.name}-worker-sg" })
}

# =============================================================================
# CONTROL PLANE rules
# =============================================================================

# SSH (admin access)
resource "aws_security_group_rule" "cp_ssh" {
  type              = "ingress"
  security_group_id = aws_security_group.control_plane.id
  protocol          = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_blocks       = [var.ssh_allowed_cidr]
  description       = "SSH"
}

# Kubernetes API server - for kubectl from your laptop
resource "aws_security_group_rule" "cp_api_external" {
  type              = "ingress"
  security_group_id = aws_security_group.control_plane.id
  protocol          = "tcp"
  from_port         = 6443
  to_port           = 6443
  cidr_blocks       = [var.api_allowed_cidr]
  description       = "Kubernetes API (kubectl)"
}

# All traffic FROM workers (kubelet -> api, pod networking, etc.)
resource "aws_security_group_rule" "cp_from_workers" {
  type                     = "ingress"
  security_group_id        = aws_security_group.control_plane.id
  protocol                 = "-1"
  from_port                = 0
  to_port                  = 0
  source_security_group_id = aws_security_group.worker.id
  description              = "All traffic from worker nodes"
}

# All traffic from itself
resource "aws_security_group_rule" "cp_self" {
  type              = "ingress"
  security_group_id = aws_security_group.control_plane.id
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
  self              = true
  description       = "All traffic from control plane itself"
}

resource "aws_security_group_rule" "cp_egress" {
  type              = "egress"
  security_group_id = aws_security_group.control_plane.id
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow all outbound"
}

# =============================================================================
# WORKER rules
# =============================================================================

# SSH (admin access / debugging)
resource "aws_security_group_rule" "worker_ssh" {
  type              = "ingress"
  security_group_id = aws_security_group.worker.id
  protocol          = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_blocks       = [var.ssh_allowed_cidr]
  description       = "SSH"
}

# App traffic via NodePort range (ingress-nginx / Services)
resource "aws_security_group_rule" "worker_nodeport" {
  type              = "ingress"
  security_group_id = aws_security_group.worker.id
  protocol          = "tcp"
  from_port         = 30000
  to_port           = 32767
  cidr_blocks       = [var.ingress_allowed_cidr]
  description       = "NodePort range (app/ingress)"
}

# All traffic FROM the control plane
resource "aws_security_group_rule" "worker_from_cp" {
  type                     = "ingress"
  security_group_id        = aws_security_group.worker.id
  protocol                 = "-1"
  from_port                = 0
  to_port                  = 0
  source_security_group_id = aws_security_group.control_plane.id
  description              = "All traffic from control plane"
}

# All traffic from other workers (pod-to-pod, CNI)
resource "aws_security_group_rule" "worker_self" {
  type              = "ingress"
  security_group_id = aws_security_group.worker.id
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
  self              = true
  description       = "All traffic between worker nodes"
}

resource "aws_security_group_rule" "worker_egress" {
  type              = "egress"
  security_group_id = aws_security_group.worker.id
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow all outbound"
}
