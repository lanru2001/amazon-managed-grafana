terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    grafana = {
      source  = "grafana/grafana"
      version = "3.13.2"
    }
  }

  backend "s3" {}
  
}
provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Environment = "staging"
      Terraform   = "true"
      Project     = "stag"
    }
  }
}


provider "grafana" {
  alias = "cloud"

  url  = "https://${module.managed_grafana.workspace_endpoint}"
  auth = module.managed_grafana.workspace_service_account_tokens.terraform.key
}
