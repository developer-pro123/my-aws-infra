terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws   = { source = "hashicorp/aws", version = "~> 5.40" }
    local = { source = "hashicorp/local", version = "~> 2.5" } # writes the inventory file
  }
}
provider "aws" {
  region = var.region
}
