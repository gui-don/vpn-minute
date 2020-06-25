output "public_ip" {
  value = data.aws_instance.this.public_ip
}

output "instance_id" {
  value = data.aws_instance.this.id
}

output "uuid" {
  value = local.uuid
}

output "known_hosts" {
  value = var.allow_ssh ? data.aws_ssm_parameter.this_known_hosts.*.value[0] : ""
}

output "region" {
  value = var.region
}
