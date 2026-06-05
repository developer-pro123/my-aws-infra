output "public_ip" {
  description = "Public IP of the dev server"
  value       = aws_eip.app.public_ip
}
output "ssh_command" {
  value = "ssh -i ${var.ssh_private_key_path} ubuntu@${aws_eip.app.public_ip}"
}
