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
  vpc_security_group_ids               = [aws_security_group.build.id]
  instance_initiated_shutdown_behavior = "terminate"

  user_data = templatefile("${path.module}/userdata.ps1", {
    github_username = var.github_username
    github_password = var.github_password
    choco_key       = var.choco_key
    branch          = var.branch
  })

  tags = {
    Name = "paket-choco-build"
  }
}
