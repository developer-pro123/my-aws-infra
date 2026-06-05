# --- Networking ---------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block           = "10.20.0.0/16"
  enable_dns_hostnames = true
  tags                 = { Name = var.project, Project = var.project }
}
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.20.1.0/24"
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true
  tags                    = { Name = "${var.project}-public" }
}
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.project}-igw" }
}
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}
# --- Firewall (security group) -----------------------------------------
resource "aws_security_group" "ec2" {
  name   = "${var.project}-sg"
  vpc_id = aws_vpc.main.id
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }
  ingress {
    description = "backend"
    from_port   = 9001
    to_port     = 9001
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.project}-sg"
  }
}
# --- SSH key (Terraform registers your PUBLIC key with AWS) -------------
resource "aws_key_pair" "main" {
  key_name   = "${var.project}-key"
  public_key = file(var.ssh_public_key_path)
}
# --- Latest Ubuntu 22.04 image -----------------------------------------
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}
# --- The server ---------------------------------------------------------
resource "aws_instance" "app" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.ec2.id]
  key_name               = aws_key_pair.main.key_name
  root_block_device { volume_size = 20 }
  tags = {
    Name    = "${var.project}-app",
    Project = var.project
  }
}
# --- Stable public IP ---------------------------------------------------
resource "aws_eip" "app" {
  instance = aws_instance.app.id
  tags = {
    Name = "${var.project}-eip"
  }
}
resource "local_file" "ansible_inventory" {
 content = templatefile("${path.module}/inventory.tmpl", {
 public_ip = aws_eip.app.public_ip
 })
 filename = "${path.module}/../ansible/inventory.ini"
}