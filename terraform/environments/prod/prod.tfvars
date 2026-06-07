###############################################################################
# PROD environment values
#   - baseline 1 worker (right-sized for normal load)
#   - scales to 5 workers automatically for campaign bursts
#   - multi-AZ + NAT-per-AZ for high availability
###############################################################################

project = "crm"
env     = "prod"
region  = "ap-south-1"

# --- Network: 2 AZs, managed NAT gateway per AZ (HA) ---
vpc_cidr             = "10.30.0.0/16"
azs                  = ["ap-south-1a", "ap-south-1b"]
public_subnet_cidrs  = ["10.30.1.0/24", "10.30.2.0/24"]
private_subnet_cidrs = ["10.30.11.0/24", "10.30.12.0/24"]
enable_nat_gateway   = true  # prod uses a reliable managed NAT gateway
single_nat_gateway   = false # one NAT per AZ (no single point of failure)

# --- Compute ---
control_plane_instance_type = "t3.medium"
worker_instance_type        = "t3.small"
worker_min_size             = 1 # baseline
worker_max_size             = 5 # campaign peak
worker_desired_capacity     = 1
k8s_version                 = "1.30"

# --- Access (TODO: lock SSH/API to your office IP/32) ---
ssh_allowed_cidr     = "0.0.0.0/0"
api_allowed_cidr     = "0.0.0.0/0"
ingress_allowed_cidr = "0.0.0.0/0"

# --- SSH keys ---
ssh_public_key_path  = "~/.ssh/crm_dev_ed25519.pub"
ssh_private_key_path = "~/.ssh/crm_dev_ed25519"
