variable "aws_region" {
  description = "AWS region to deploy to"
  type        = string
  default     = "us-east-2"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "auto-cloud-platform"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "app_image" {
  description = "Docker image for the application"
  type        = string
  default     = "nginx:alpine" # Default for first run
}
