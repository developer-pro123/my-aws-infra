terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws   = { source = "hashicorp/aws", version = "~> 5.40" }
    local = { source = "hashicorp/local", version = "~> 2.5" }
  }
}

provider "aws" {
  region = var.region
}
