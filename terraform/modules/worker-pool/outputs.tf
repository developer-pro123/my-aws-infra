###############################################################################
# worker-pool module - outputs
###############################################################################

output "asg_name" {
  description = "Name of the worker Auto Scaling Group"
  value       = aws_autoscaling_group.worker.name
}

output "asg_arn" {
  description = "ARN of the worker Auto Scaling Group"
  value       = aws_autoscaling_group.worker.arn
}

output "launch_template_id" {
  description = "ID of the worker launch template"
  value       = aws_launch_template.worker.id
}

output "worker_iam_role_name" {
  description = "Worker IAM role name"
  value       = aws_iam_role.worker.name
}
