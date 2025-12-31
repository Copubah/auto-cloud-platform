output "vpc_id" {
  value = module.vpc.vpc_id
}

output "alb_dns_name" {
  value = module.alb.alb_dns_name
}

output "db_endpoint" {
  value = module.database.db_endpoint
}

output "ecr_repository_url" {
  value = module.compute.ecr_repository_url
}
output "region" {
  value = var.aws_region
}
output "ecs_cluster_name" {
  value = module.compute.ecs_cluster_name
}

output "ecs_service_name" {
  value = module.compute.ecs_service_name
}
