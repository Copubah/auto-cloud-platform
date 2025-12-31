module "vpc" {
  source       = "./modules/vpc"
  project_name = var.project_name
  environment  = var.environment
}

module "security" {
  source       = "./modules/security"
  project_name = var.project_name
  environment  = var.environment
  vpc_id       = module.vpc.vpc_id
}

module "database" {
  source             = "./modules/database"
  project_name       = var.project_name
  environment        = var.environment
  private_subnet_ids = module.vpc.private_subnet_ids
  rds_sg_id          = module.security.rds_sg_id
}

module "alb" {
  source            = "./modules/alb"
  project_name      = var.project_name
  environment       = var.environment
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  alb_sg_id         = module.security.alb_sg_id
}

module "compute" {
  source             = "./modules/compute"
  project_name       = var.project_name
  environment        = var.environment
  aws_region         = var.aws_region
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  ecs_sg_id          = module.security.ecs_tasks_sg_id
  target_group_arn   = module.alb.target_group_arn

  db_endpoint   = module.database.db_endpoint
  db_name       = module.database.db_name
  db_secret_arn = module.database.secret_arn

  app_image = var.app_image
}

resource "aws_guardduty_detector" "main" {
  enable = true

  tags = {
    Name = "GuardDuty-${var.project_name}-${var.environment}"
  }
}
