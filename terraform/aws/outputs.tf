output "public_ip" {
  value = data.aws_instance.this.public_ip
}

output "instance_id" {
  value = data.aws_instance.this.id
}

output "uuid" {
  value = local.uuid
}

output "ssh_known_hosts" {
  value = var.allow_ssh ? data.aws_ssm_parameter.this_known_hosts.*.value[0] : "not applicable"
}

output "region" {
  value = var.region
}
