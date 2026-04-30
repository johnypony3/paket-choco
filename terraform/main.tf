terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
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

data "aws_vpc" "default" {
  default = true
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

resource "aws_security_group" "build" {
  name        = "paket-choco-build"
  description = "Outbound only for package build instance"
  vpc_id      = data.aws_vpc.default.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "build" {
  ami                                  = data.aws_ami.windows_2019.id
  instance_type                        = "t3.medium"
  iam_instance_profile                 = aws_iam_instance_profile.build.name
  vpc_security_group_ids               = [aws_security_group.build.id]
  instance_initiated_shutdown_behavior = "terminate"

  user_data = templatefile("${path.module}/userdata.ps1", {
    branch = var.branch
  })

  tags = {
    Name = "paket-choco-build"
  }
}
