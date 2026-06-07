terraform {
  backend "s3" {
    bucket       = "crm-dev-tfstate-jayhind"
    key          = "dev/terraform.tfstate" # <-- dev's own state file
    region       = "ap-south-1"
    use_lockfile = true
  }
}
