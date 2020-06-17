variable "vpc_id" {
  description = "ID of the VPC (leave empty to use default VPC)"
  default     = ""
}

variable "ami_id" {
  description = "ID of the Amazon Image to use (leave empty to use the latest Ubunut 18.04)"
  default     = ""
}

variable "subnet_id" {
  description = "ID of the subnet use to deploy wireguard instance (leave empty to use default subnet)"
  default     = ""
}

variable "instance_type" {
  description = "Type of instance that will run Wireguard"
  default     = "t3.nano"
}

variable "public_key" {
  description = "Public ssh key"
  type = string
}

variable "allow_ssh" {
  description = "Allow inbound ssh"
  type = bool
}

variable "access_key" {
  description = "Credentials: AWS access key."
  type        = string
}

variable "secret_key" {
  description = "Credentials: AWS secret key. Pass this as a variable, never write password in the code."
  type        = string
}

variable "region" {
  description = "AWS region where resources will be created"
  type        = string
}
