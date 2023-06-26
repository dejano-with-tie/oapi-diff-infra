variable "organization_name" {
  type    = string
}

variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "aws_region" {
  type        = string
}

variable "aws_region_us" {
  type        = string
}

variable "primary_domain" {
  type        = string
  description = "Primary domain"
}
