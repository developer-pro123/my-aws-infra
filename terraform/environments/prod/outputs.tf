###############################################################################
# Environment outputs
###############################################################################

output "cluster_name" {
  value = local.cluster_name
}

output "control_plane_public_ip" {
  description = "Public IP of the control plane (kubectl/SSH endpoint)"
  value       = module.control_plane.public_ip
}

output "control_plane_private_ip" {
  value = module.control_plane.private_ip
}

output "ssh_command" {
  description = "SSH into the control plane"
  value       = "ssh -i ${var.ssh_private_key_path} ubuntu@${module.control_plane.public_ip}"
}

output "worker_asg_name" {
  description = "Worker Auto Scaling Group name"
  value       = module.worker_pool.asg_name
}

output "worker_scaling_bounds" {
  description = "Autoscaling bounds for the worker pool"
  value       = "min=${var.worker_min_size}, max=${var.worker_max_size}"
}

output "join_command_ssm_param" {
  description = "SSM parameter Ansible must populate with the kubeadm join command"
  value       = aws_ssm_parameter.join_command.name
}

output "next_steps" {
  value = "1) terraform apply  2) run Ansible playbooks/cluster.yml (inits master, writes join cmd to SSM)  3) workers auto-join"
}
