resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group-${var.environment}"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name = "${var.project_name}-db-subnet-group-${var.environment}"
  }
}

resource "random_password" "password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "db_password" {
  name = "${var.project_name}/db-password/${var.environment}"
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = random_password.password.result
}

resource "aws_db_instance" "main" {
  identifier        = "${var.project_name}-db-${var.environment}"
  engine            = "postgres"
  engine_version    = "14.10" # Recent stable version
  instance_class    = var.db_instance_class
  allocated_storage = 20
  storage_type      = "gp3"

  username = var.db_username
  password = random_password.password.result

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.rds_sg_id]

  skip_final_snapshot = true # For demo/easy destruction. Set to false for real prod.
  publicly_accessible = false

  tags = {
    Name = "${var.project_name}-db-${var.environment}"
  }
}
