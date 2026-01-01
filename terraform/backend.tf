terraform {
  backend "s3" {
    bucket         = "terraform-state-backend-12061"
    key            = "global/s3/terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "terraform-locks-12061"
    encrypt        = true
  }
}
