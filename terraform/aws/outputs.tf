output "public_ip" {
  value = data.aws_instance.this.public_ip
}

output "instance_id" {
  value = data.aws_instance.this.id
}
