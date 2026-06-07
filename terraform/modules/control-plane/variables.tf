###############################################################################
# control-plane module - input variables
###############################################################################

variable "name" {
  description = "Name prefix, e.g. crm-dev"
  type        = string
}

variable "cluster_name" {
  description = "Kubernetes cluster name (used for the kubernetes.io/cluster tag)"
  type        = string
}

variable "ami_id" {
  description = "AMI ID for the control plane node (Ubuntu 22.04)"
  type        = string
}

variable "instance_type" {
  description = "Instance type for the control plane (>= t3.medium recommended for kubeadm)"
  type        = string
  default     = "t3.medium"
}

variable "subnet_id" {
  description = "PUBLIC subnet ID where the control plane lives (needs an EIP for kubectl access)"
  type        = string
}

variable "security_group_id" {
  description = "Control plane security group ID"
  type        = string
}

variable "key_name" {
  description = "EC2 key pair name for SSH"
  type        = string
}

variable "root_volume_size" {
  description = "Root EBS volume size in GB"
  type        = number
  default     = 30
}

variable "ssm_join_param_arn" {
  description = "ARN of the SSM parameter where kubeadm join command is stored (control plane WRITES it)"
  type        = string
}

variable "asg_name" {
  description = "Worker ASG name the Cluster Autoscaler is allowed to scale (for the IAM policy)"
  type        = string
  default     = "*"
}

# --- Act as a NAT instance for private subnets (dev cost-saver) --------------
variable "act_as_nat" {
  description = "If true, the control plane also forwards/NATs internet traffic for private subnets (free alternative to a NAT gateway, for dev)."
  type        = bool
  default     = false
}

variable "private_route_table_ids" {
  description = "Private route table IDs to add a default route into (only used when act_as_nat = true)."
  type        = list(string)
  default     = []
}

# --- Ansible inventory generation -------------------------------------------
variable "ansible_inventory_path" {
  description = "Where to write the generated Ansible inventory file"
  type        = string
}

variable "ssh_user" {
  description = "SSH user for Ansible (Ubuntu AMI = ubuntu)"
  type        = string
  default     = "ubuntu"
}

variable "ssh_private_key_path" {
  description = "Path to the SSH private key Ansible uses"
  type        = string
}

variable "tags" {
  description = "Extra tags."
  type        = map(string)
  default     = {}
}
