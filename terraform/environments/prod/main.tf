###############################################################################
# Environment root - calls the modules to build ONE complete cluster.
# Identical to dev/main.tf - only the values (prod.tfvars) and backend differ.
###############################################################################

locals {
  cluster_name = "${var.project}-${var.env}" # e.g. crm-prod
  name         = local.cluster_name

  tags = {
    Project     = var.project
    Environment = var.env
    ManagedBy   = "terraform"
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_key_pair" "main" {
  key_name   = "${local.name}-key"
  public_key = file(pathexpand(var.ssh_public_key_path))
  tags       = local.tags
}

resource "aws_ssm_parameter" "join_command" {
  name  = "/${local.cluster_name}/k8s/join-command"
  type  = "SecureString"
  value = "PLACEHOLDER"
  tags  = local.tags

  lifecycle {
    ignore_changes = [value]
  }
}

# --- Modules ----------------------------------------------------------------
module "vpc" {
  source = "../../modules/vpc"

  name                 = local.name
  cluster_name         = local.cluster_name
  vpc_cidr             = var.vpc_cidr
  azs                  = var.azs
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  enable_nat_gateway   = var.enable_nat_gateway
  single_nat_gateway   = var.single_nat_gateway
  tags                 = local.tags
}

module "security" {
  source = "../../modules/security"

  name                 = local.name
  vpc_id               = module.vpc.vpc_id
  ssh_allowed_cidr     = var.ssh_allowed_cidr
  api_allowed_cidr     = var.api_allowed_cidr
  ingress_allowed_cidr = var.ingress_allowed_cidr
  tags                 = local.tags
}

module "control_plane" {
  source = "../../modules/control-plane"

  name              = local.name
  cluster_name      = local.cluster_name
  ami_id            = data.aws_ami.ubuntu.id
  instance_type     = var.control_plane_instance_type
  subnet_id         = module.vpc.public_subnet_ids[0]
  security_group_id = module.security.control_plane_sg_id
  key_name          = aws_key_pair.main.key_name

  ssm_join_param_arn = aws_ssm_parameter.join_command.arn

  # In prod NAT gateway is used, so the control plane does NOT act as NAT.
  act_as_nat              = !var.enable_nat_gateway
  private_route_table_ids = module.vpc.private_route_table_ids

  ansible_inventory_path = "${path.module}/../../../ansible/inventory/${var.env}.ini"
  ssh_private_key_path   = var.ssh_private_key_path

  tags = local.tags
}

module "worker_pool" {
  source = "../../modules/worker-pool"

  name              = local.name
  cluster_name      = local.cluster_name
  ami_id            = data.aws_ami.ubuntu.id
  instance_type     = var.worker_instance_type
  subnet_ids        = module.vpc.private_subnet_ids
  security_group_id = module.security.worker_sg_id
  key_name          = aws_key_pair.main.key_name

  min_size         = var.worker_min_size
  max_size         = var.worker_max_size
  desired_capacity = var.worker_desired_capacity

  ssm_join_param_name = aws_ssm_parameter.join_command.name
  ssm_join_param_arn  = aws_ssm_parameter.join_command.arn
  k8s_version         = var.k8s_version
  region              = var.region

  tags = local.tags
}
