###############################################################################
# control-plane module - outputs
###############################################################################

output "instance_id" {
  description = "EC2 instance ID of the control plane"
  value       = aws_instance.control_plane.id
}

output "public_ip" {
  description = "Elastic IP of the control plane (kubectl/SSH endpoint)"
  value       = aws_eip.control_plane.public_ip
}

output "private_ip" {
  description = "Private IP of the control plane (workers join via this inside the VPC)"
  value       = aws_instance.control_plane.private_ip
}

output "iam_role_name" {
  description = "Control plane IAM role name"
  value       = aws_iam_role.control_plane.name
}
