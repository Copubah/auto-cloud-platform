variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "ecs_sg_id" {
  type = string
}

variable "target_group_arn" {
  type = string
}

variable "container_port" {
  type    = number
  default = 8000
}

variable "fargate_cpu" {
  type    = number
  default = 256
}

variable "fargate_memory" {
  type    = number
  default = 512
}

variable "app_count" {
  type    = number
  default = 1
}

variable "app_image" {
  type        = string
  description = "Docker image to run in the ECS task"
  default     = "nginx:alpine" # Default to nginx for initial infra bring-up
}

variable "db_endpoint" {
  type = string
}

variable "db_name" {
  type = string
}

variable "db_secret_arn" {
  type = string
}
