###############################################################################
# VPC module - network for a self-managed Kubernetes cluster
#
# Pieces created here:
#   aws_vpc                       the network
#   aws_subnet (public)           internet-facing: ingress LB + NAT live here
#   aws_subnet (private)          K8s nodes live here (no public IP)
#   aws_internet_gateway          gives public subnets internet access
#   aws_eip + aws_nat_gateway     gives private subnets OUTBOUND internet
#   aws_route_table (public)      0.0.0.0/0 -> internet gateway
#   aws_route_table (private)     0.0.0.0/0 -> NAT gateway
#   *_route_table_association     wires each subnet to its route table
###############################################################################

locals {
  # Common tags merged onto everything.
  common_tags = merge(var.tags, {
    Name = var.name
  })

  # Kubernetes needs this tag on subnets so the cloud integration / autoscaler
  # can discover them. "shared" = the cluster does not own the VPC exclusively.
  k8s_cluster_tag = { "kubernetes.io/cluster/${var.cluster_name}" = "shared" }

  # How many NAT gateways to build:
  #   0                  if NAT is disabled (dev routes through control-plane instead)
  #   1                  if single_nat_gateway (cheap)
  #   one per AZ         otherwise (prod HA)
  nat_gateway_count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.azs)) : 0
}

# --- The VPC ----------------------------------------------------------------
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true # required for Kubernetes DNS
  enable_dns_hostnames = true # required so instances get DNS names

  tags = merge(local.common_tags, { Name = "${var.name}-vpc" })
}

# --- Public subnets (one per AZ) --------------------------------------------
resource "aws_subnet" "public" {
  count = length(var.azs)

  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, local.k8s_cluster_tag, {
    Name                     = "${var.name}-public-${var.azs[count.index]}"
    "kubernetes.io/role/elb" = "1" # public load balancers go here
  })
}

# --- Private subnets (one per AZ) -------------------------------------------
resource "aws_subnet" "private" {
  count = length(var.azs)

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index]

  tags = merge(local.common_tags, local.k8s_cluster_tag, {
    Name                              = "${var.name}-private-${var.azs[count.index]}"
    "kubernetes.io/role/internal-elb" = "1" # internal LBs go here
  })
}

# --- Internet Gateway (one per VPC) -----------------------------------------
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = merge(local.common_tags, { Name = "${var.name}-igw" })
}

# --- Elastic IPs for the NAT gateway(s) -------------------------------------
resource "aws_eip" "nat" {
  count  = local.nat_gateway_count
  domain = "vpc"
  tags   = merge(local.common_tags, { Name = "${var.name}-nat-eip-${count.index}" })

  depends_on = [aws_internet_gateway.this]
}

# --- NAT Gateway(s) ----------------------------------------------------------
# Always placed in a PUBLIC subnet. Private subnets route outbound through it.
resource "aws_nat_gateway" "this" {
  count = local.nat_gateway_count

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags       = merge(local.common_tags, { Name = "${var.name}-nat-${count.index}" })
  depends_on = [aws_internet_gateway.this]
}

# --- Public route table: send internet traffic to the IGW -------------------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(local.common_tags, { Name = "${var.name}-public-rt" })
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# --- Private route tables ----------------------------------------------------
# One per AZ. The default (0.0.0.0/0) route is added separately below so it can
# point EITHER at a NAT gateway (prod) OR be left for the control-plane NAT
# instance to fill in (dev) - avoiding a module dependency cycle.
resource "aws_route_table" "private" {
  count  = length(var.azs)
  vpc_id = aws_vpc.this.id

  tags = merge(local.common_tags, { Name = "${var.name}-private-rt-${var.azs[count.index]}" })
}

# Default route via NAT gateway - only when NAT is enabled (prod).
resource "aws_route" "private_nat" {
  count                  = var.enable_nat_gateway ? length(var.azs) : 0
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  # single_nat_gateway: everyone uses NAT[0]. Otherwise: NAT in the same AZ.
  nat_gateway_id = var.single_nat_gateway ? aws_nat_gateway.this[0].id : aws_nat_gateway.this[count.index].id
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}
