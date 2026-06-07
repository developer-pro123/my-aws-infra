###############################################################################
# VPC module - input variables
###############################################################################

variable "name" {
  description = "Name prefix for all resources (usually \"<project>-<env>\", e.g. crm-prod)"
  type        = string
}

variable "cluster_name" {
  description = "Kubernetes cluster name - used for the kubernetes.io/cluster/* subnet tags so the cloud provider and Cluster Autoscaler can discover subnets."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the whole VPC, e.g. 10.20.0.0/16"
  type        = string
  default     = "10.20.0.0/16"
}

variable "azs" {
  description = "List of Availability Zones to spread subnets across. 1 AZ for dev, 2-3 for prod HA."
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDR per public subnet. Must have the same length as `azs`. Public = internet-facing (ingress LB, NAT)."
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR per private subnet. Must have the same length as `azs`. Private = K8s nodes (no public IP)."
  type        = list(string)
}

variable "enable_nat_gateway" {
  description = "true = create managed NAT gateway(s) (prod). false = no NAT GW; private subnets get internet some other way, e.g. routed through the control-plane NAT instance (dev, free)."
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Only used when enable_nat_gateway = true. true = one shared NAT GW (cheap). false = one NAT GW per AZ (HA, for prod)."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Extra tags applied to every resource."
  type        = map(string)
  default     = {}
}
