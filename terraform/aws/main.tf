locals {
  is_default_vpc   = "" == var.vpc_id
  is_defaut_ami_id = "" == var.ami_id
  prefix           = "vpnm"
  uuid             = var.uuid != "" ? var.uuid : random_string.this.result
  name             = "${local.prefix}-${local.uuid}"
  tags = {
    managed-by  = "Terraform"
    application = var.application_name
    uuid        = local.uuid
  }
}

resource "random_string" "this" {
  length  = 8
  special = false
  upper   = false
}

####
# Security Group
####

resource "aws_security_group" "this" {
  name        = "sgs-${local.name}"
  description = "${var.application_name} security group for instance ${local.uuid}"
  vpc_id      = "" == var.vpc_id ? data.aws_vpc.default.0.id : var.vpc_id

  tags = merge(
    local.tags,
    {
      Name = "sgs-${local.name}"
    }
  )
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

####
# Compute
####

resource "aws_key_pair" "this" {
  count = var.allow_ssh ? 1 : 0

  key_name   = "ssh-${local.name}"
  public_key = var.public_key

  tags = merge(
    local.tags,
    {
      Name = "ssh-${local.name}"
    }
  )
}

resource "aws_launch_template" "this" {
  name = local.name

  image_id      = local.is_default_vpc ? data.aws_ami.ami.0.id : var.ami_id
  instance_type = var.instance_type

  user_data = base64encode(replace(data.template_file.user_data.rendered, "\r\n", "\n"))

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
      volume_size           = lookup(local.ami_size, var.ami_os)
      volume_type           = "gp2"
    }
  }

  dynamic "iam_instance_profile" {
    for_each = var.allow_ssh ? [1] : []

    content {
      name = element(aws_iam_instance_profile.this.*.name, 0)
    }
  }

  key_name = var.allow_ssh ? element(aws_key_pair.this.*.key_name, 0) : null

  tag_specifications {
    resource_type = "volume"

    tags = merge(
      local.tags,
      {
        Name = "ebs-${local.name}"
      }
    )
  }

  tags = merge(
    local.tags,
    {
      Name = "ltp-${local.name}"
    }
  )

  lifecycle {
    ignore_changes = [user_data]
  }
}

resource "aws_spot_fleet_request" "this" {
  iam_fleet_role  = aws_iam_role.this_spotfleet.arn
  target_capacity = 1
  valid_until     = timeadd(timestamp(), "86400h")

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

  tags = merge(
    local.tags,
    {
      Name = "sfr-${local.name}"
    }
  )
}

####
# SSM Parameter
####

resource "aws_ssm_parameter" "this_known_hosts" {
  count  = var.allow_ssh ? 1 : 0

  name        = "/${local.prefix}/${local.uuid}/known-hosts"
  description = "${var.application_name} server ${local.uuid} known hosts in base64."
  type        = "String"
  value       = "IN PROGRESS..."
  overwrite   = true

  tags = merge(
    local.tags,
    {
      Name = "ssm-${local.name}"
    }
  )

  lifecycle {
    ignore_changes = [value]
  }
}

####
# IAM Policy/Role/Instance Profile
####

data "aws_iam_policy_document" "spotfleet" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type = "Service"
      identifiers = [
        "spotfleet.amazonaws.com"
      ]
    }
  }
}

resource "aws_iam_role" "this_spotfleet" {
  name = "rol-spf-${local.name}"

  description        = "${var.application_name} role for sfr-${local.name}."
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.spotfleet.json

  tags = merge(
    local.tags,
    {
      Name = "rol-spf-${local.name}"
    }
  )
}

resource "aws_iam_role_policy_attachment" "this_spotfleet" {
  role       = aws_iam_role.this_spotfleet.id
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2SpotFleetTaggingRole"
}

data "aws_iam_policy_document" "this" {
  count  = var.allow_ssh ? 1 : 0

  statement {
    sid = "VPNMAllowReadSSMParameterAccess"

    effect = "Allow"

    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:PutParameter",
    ]

    resources = formatlist(
      "arn:aws:ssm:*:%s:parameter/%s/%s/known-hosts",
      data.aws_caller_identity.current.account_id,
      local.prefix,
      local.uuid,
    )
  }
}

data "aws_iam_policy_document" "sts_instance" {
  count  = var.allow_ssh ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type = "Service"
      identifiers = [
        "ec2.amazonaws.com"
      ]
    }
  }
}

resource "aws_iam_policy" "this_instance_profile" {
  count  = var.allow_ssh ? 1 : 0

  name        = "plc-${local.name}"
  path        = "/"
  policy      = element(concat(data.aws_iam_policy_document.this.*.json, [""]), 0)
  description = "${var.application_name} read/write policy to get access to ssm-${local.name} SSM parameters."
}

resource "aws_iam_role" "this_instance_profile" {
  count  = var.allow_ssh ? 1 : 0

  name = "rol-ipr-${local.name}"

  description        = "${var.application_name} role for ipr-${local.name} instance profile."
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.sts_instance.*.json[0]

  tags = merge(
    local.tags,
    {
      Name = "rol-ipr-${local.name}"
    }
  )
}

resource "aws_iam_role_policy_attachment" "this_instance_profile" {
  count  = var.allow_ssh ? 1 : 0

  role       = element(aws_iam_role.this_instance_profile.*.id, 0)
  policy_arn = element(aws_iam_policy.this_instance_profile.*.arn, 0)
}

resource "aws_iam_instance_profile" "this" {
  count  = var.allow_ssh ? 1 : 0

  name = "ipr-${local.name}"
  path = "/"

  roles = [element(aws_iam_role.this_instance_profile.*.id, 0)]
}
