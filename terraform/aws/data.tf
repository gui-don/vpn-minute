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

data "aws_instance" "this" {
  filter {
    name   = "tag:aws:ec2spot:fleet-request-id"
    values = [aws_spot_fleet_request.this.id]
  }
}

data "template_file" "user_data" {
  template = file("${path.module}/templates/user_data.tmpl")
  vars = {
    allow_ssh                     = var.allow_ssh
    region                        = var.region
    base64_wg_server_config       = var.base64_vpn_server_config
    known_host_ssm_parameter_name = var.allow_ssh ? element(aws_ssm_parameter.this_known_hosts.*.name, 0) : ""
  }
}

data "aws_ssm_parameter" "this_known_hosts" {
  count = var.allow_ssh ? 1 : 0

  name = element(aws_ssm_parameter.this_known_hosts.*.name, 0)
}

