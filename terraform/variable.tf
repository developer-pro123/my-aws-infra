variable "region" { default = "ap-south-1" }
variable "instance_type" { default = "t3.small" }
variable "project" { default = "crm-dev" }
# Lock SSH to YOUR public IP only. Find it: curl ifconfig.me
variable "my_ip" {
  description = "Your laptop public IP in CIDR form, e.g. 49.36.10.20/32"
  type        = string
}
# Path to the SSH key Ansible will use to log in (you create it once, see run steps)
variable "ssh_public_key_path" { default = "~/.ssh/crm_dev_ed25519.pub" }
variable "ssh_private_key_path" { default = "~/.ssh/crm_dev_ed25519" }
