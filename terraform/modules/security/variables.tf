###############################################################################
# security module - input variables
###############################################################################

variable "name" {
  description = "Name prefix, e.g. crm-dev"
  type        = string
}

variable "vpc_id" {
  description = "VPC the security groups belong to"
  type        = string
}

variable "ssh_allowed_cidr" {
  description = "CIDR allowed to SSH (port 22) into the nodes. Lock to your IP in prod."
  type        = string
}

variable "api_allowed_cidr" {
  description = "CIDR allowed to reach the Kubernetes API server (port 6443) for kubectl."
  type        = string
}

variable "ingress_allowed_cidr" {
  description = "CIDR allowed to reach the app via NodePort range / ingress. 0.0.0.0/0 for a public CRM."
  type        = string
  default     = "0.0.0.0/0"
}

variable "tags" {
  description = "Extra tags."
  type        = map(string)
  default     = {}
}
