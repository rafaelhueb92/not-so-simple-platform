output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_connection_commands" {
  value = module.eks.cluster_connection_commands
}

output "ecr_registry_url" {
  value = aws_ecr_repository.hello.registry_id
}

output "ecr_repository_url" {
  value = aws_ecr_repository.hello.name
}