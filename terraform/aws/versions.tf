terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 2.60"
    }
    random = {
      source = "hashicorp/random"
      version = "~> 2.0"
    }
    template = {
      source = "hashicorp/template"
      version = "~> 2.0"
    }
  }
}
