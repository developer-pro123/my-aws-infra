###############################################################################
# worker-pool module - input variables
###############################################################################

variable "name" {
  description = "Name prefix, e.g. crm-dev"
  type        = string
}

variable "cluster_name" {
  description = "Kubernetes cluster name (used for ASG tags the Cluster Autoscaler discovers)"
  type        = string
}

variable "ami_id" {
  description = "AMI ID for worker nodes (Ubuntu 22.04)"
  type        = string
}

variable "instance_type" {
  description = "Worker instance type"
  type        = string
  default     = "t3.small"
}

variable "subnet_ids" {
  description = "PRIVATE subnet IDs the ASG launches workers into (spread across AZs)"
  type        = list(string)
}

variable "security_group_id" {
  description = "Worker security group ID"
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

# --- Autoscaling bounds (the campaign-burst knobs) --------------------------
variable "min_size" {
  description = "Minimum worker count (baseline). 1 for normal load."
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum worker count (campaign peak). e.g. 5"
  type        = number
  default     = 3
}

variable "desired_capacity" {
  description = "Initial desired count. Cluster Autoscaler manages it afterwards."
  type        = number
  default     = 1
}

# --- Cluster join -----------------------------------------------------------
variable "ssm_join_param_name" {
  description = "Name of the SSM parameter holding the kubeadm join command (workers READ it)"
  type        = string
}

variable "ssm_join_param_arn" {
  description = "ARN of the SSM parameter (for the worker IAM read policy)"
  type        = string
}

variable "k8s_version" {
  description = "Kubernetes minor version to install on workers, e.g. 1.30"
  type        = string
  default     = "1.30"
}

variable "region" {
  description = "AWS region (workers use it to read SSM)"
  type        = string
}

variable "tags" {
  description = "Extra tags."
  type        = map(string)
  default     = {}
}
