terraform {
  backend "s3" {
    bucket       = "crm-dev-tfstate-jayhind"
    key          = "prod/terraform.tfstate" # <-- prod's own state file (isolated from dev)
    region       = "ap-south-1"
    use_lockfile = true
  }
}
