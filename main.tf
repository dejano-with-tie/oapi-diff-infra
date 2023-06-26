provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Org         = var.organization_name
      Project     = var.project_name
      Environment = var.environment
      Terraform   = "true"
      Source      = "infra-tf-global"
    }
  }
}

provider "aws" {
  region = var.aws_region_us
  alias  = "us"
}