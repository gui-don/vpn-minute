locals {
  is_default_vpc   = "" == var.vpc_id
  is_defaut_ami_id = "" == var.ami_id
}

resource "random_string" "this" {
  length  = 6
  special = false
  upper   = false
}

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
  name        = "wireguard-sg-${random_string.this.result}"
  description = "Security group for wireguard instance ${random_string.this.result}"
  vpc_id      = "" == var.vpc_id ? data.aws_vpc.default.0.id : var.vpc_id

  tags = {
    Name      = "tftest-sg-${random_string.this.result}"
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
  count = var.allow_ssh ? 1 : 0
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
  key_name   = "wireguard-ssh-${random_string.this.result}"
  public_key = var.public_key
}

resource "aws_instance" "this" {
  ami           = local.is_default_vpc ? data.aws_ami.ubuntu.0.id : var.ami_id
  instance_type = var.instance_type

  vpc_security_group_ids      = [aws_security_group.this.id]
  subnet_id                   = "" == var.subnet_id ? tolist(element(concat(data.aws_subnet_ids.this.*.ids, [""]), 0))[0] : var.subnet_id
  associate_public_ip_address = true

  ebs_optimized = true
  root_block_device {
    delete_on_termination = true
    encrypted             = true
  }

  key_name = aws_key_pair.this.key_name

  tags = {
    Name      = "wireguard-${random_string.this.result}"
    Terraform = true
  }

  lifecycle {
    # Due to several known issues in Terraform AWS provider related to arguments of aws_instance:
    # (eg, https://github.com/terraform-providers/terraform-provider-aws/issues/2036)
    # we have to ignore changes in the following arguments
    ignore_changes = [private_ip, root_block_device, ebs_block_device, volume_tags]
  }
}
