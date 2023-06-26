terraform {

  backend "local" {
    path = ".terraform/.terraform.tfstate"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.5.0"
    }
  }

  required_version = ">= 1.3.6"
}
