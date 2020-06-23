locals {
  is_default_vpc   = "" == var.vpc_id
  is_defaut_ami_id = "" == var.ami_id
  prefix           = "vpn-minute"
}

resource "random_string" "this" {
  length  = 6
  special = false
  upper   = false
}

data "aws_caller_identity" "current" {}

data "aws_ami" "ubuntu" {
  count       = local.is_defaut_ami_id ? 1 : 0
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_vpc" "default" {
  count   = local.is_default_vpc ? 1 : 0
  default = true
}

data "aws_subnet_ids" "this" {
  count  = "" == var.subnet_id ? 1 : 0
  vpc_id = concat(data.aws_vpc.default.*.id, [""])[0]
}

resource "aws_security_group" "this" {
  name        = "${local.prefix}-sg-${random_string.this.result}"
  description = "Security group for wireguard instance ${random_string.this.result}"
  vpc_id      = "" == var.vpc_id ? data.aws_vpc.default.0.id : var.vpc_id

  tags = {
    Name      = "${local.prefix}-sg-${random_string.this.result}"
    Terraform = true
  }
}

resource "aws_security_group_rule" "this_ingress" {
  type        = "ingress"
  from_port   = 51820
  to_port     = 51820
  protocol    = "udp"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = aws_security_group.this.id
}

resource "aws_security_group_rule" "this_ingress_22" {
  count       = var.allow_ssh ? 1 : 0
  type        = "ingress"
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = aws_security_group.this.id
}

resource "aws_security_group_rule" "this_egress" {
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = -1
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = aws_security_group.this.id
}

resource "aws_key_pair" "this" {
  key_name   = "${local.prefix}-${random_string.this.result}"
  public_key = var.public_key
}

resource "aws_launch_template" "this" {
  name          = "${local.prefix}-${random_string.this.result}"

  network_interfaces {
    security_groups             = [aws_security_group.this.id]
    associate_public_ip_address = true
    delete_on_termination       = true
  }

  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      delete_on_termination = true
      encrypted             = true
      volume_size           = 8
      volume_type           = "gp2"
    }
  }

  key_name = aws_key_pair.this.key_name

  tags = {
    Name      = "${local.prefix}-${random_string.this.result}"
    Terraform = true
  }

  monitoring {
    enabled = true
  }

  image_id      = local.is_default_vpc ? data.aws_ami.ubuntu.0.id : var.ami_id
  instance_type = var.instance_type
}

resource "aws_spot_fleet_request" "this" {
  iam_fleet_role  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-ec2-spot-fleet-tagging-role"
  target_capacity = 1
  valid_until = timeadd(timestamp(), "86400h")

  terminate_instances_with_expiration = true

  launch_template_config {
    launch_template_specification {
      id      = aws_launch_template.this.*.id[0]
      version = aws_launch_template.this.*.latest_version[0]
    }
    overrides {
      subnet_id = "" == var.subnet_id ? tolist(element(concat(data.aws_subnet_ids.this.*.ids, [""]), 0))[0] : var.subnet_id
    }
  }

  lifecycle {
    ignore_changes = [valid_until]
  }
}

data "aws_instance" "this" {
  filter {
    name   = "tag:aws:ec2spot:fleet-request-id"
    values = [aws_spot_fleet_request.this.id]
  }
}
