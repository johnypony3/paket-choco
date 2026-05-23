terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = "us-west-2"
}

data "aws_ami" "windows_2019" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["Windows_Server-2019-English-Full-Base-*"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

resource "aws_vpc" "build" {
  cidr_block = "10.0.0.0/16"
  tags       = { Name = "paket-choco-build" }
}

resource "aws_subnet" "build" {
  vpc_id                  = aws_vpc.build.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  tags                    = { Name = "paket-choco-build" }
}

resource "aws_internet_gateway" "build" {
  vpc_id = aws_vpc.build.id
  tags   = { Name = "paket-choco-build" }
}

resource "aws_route_table" "build" {
  vpc_id = aws_vpc.build.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.build.id
  }
  tags = { Name = "paket-choco-build" }
}

resource "aws_route_table_association" "build" {
  subnet_id      = aws_subnet.build.id
  route_table_id = aws_route_table.build.id
}

resource "aws_iam_role" "build" {
  name = "paket-choco-build"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "ssm" {
  name = "paket-choco-ssm"
  role = aws_iam_role.build.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ssm:GetParameter"]
      Resource = "arn:aws:ssm:us-west-2:*:parameter/paket-choco/*"
    }]
  })
}

resource "aws_iam_instance_profile" "build" {
  name = "paket-choco-build"
  role = aws_iam_role.build.name
}

resource "random_password" "windows" {
  length  = 16
  special = false
}

resource "aws_ssm_parameter" "windows_password" {
  name  = "/paket-choco/windows_password"
  type  = "SecureString"
  value = random_password.windows.result
}

resource "aws_security_group" "build" {
  name        = "paket-choco-build"
  description = "WinRM and outbound for package build instance"
  vpc_id      = aws_vpc.build.id

  ingress {
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 5985
    to_port     = 5986
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "build" {
  ami                    = data.aws_ami.windows_2019.id
  instance_type          = "t3.medium"
  iam_instance_profile   = aws_iam_instance_profile.build.name
  subnet_id              = aws_subnet.build.id
  vpc_security_group_ids = [aws_security_group.build.id]

  depends_on = [aws_ssm_parameter.windows_password]

  user_data = templatefile("${path.module}/userdata.ps1", {
    branch           = var.branch
    windows_password = random_password.windows.result
  })

  tags = {
    Name = "paket-choco-build"
  }
}
