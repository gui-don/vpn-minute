####
# Credentials
####

variable "access_key" {
  description = "Credentials: AWS access key."
  type        = string
  default     = ""
}

variable "secret_key" {
  description = "Credentials: AWS secret key. Pass this as a variable, never write password in the code."
  type        = string
  default     = ""
}

variable "shared_credentials_file" {
  description = "Credentials: shared credential file."
  type        = string
  default     = ""
}

variable "uuid" {
  description = "Unique ID for the vpn-minute resources"
  type        = string
  default     = ""
}

variable "region" {
  description = "AWS region where resources will be created"
  type        = string
}

####
# Configuration
####

variable "destroy" {
  description = "This forces a destroy."
  default     = false
}

variable "vpc_id" {
  description = "ID of the VPC (leave empty to use default VPC)"
  default     = ""
}

variable "ami_os" {
  description = "What is the underlying OS to use."
  default     = "ubuntu"
}

variable "ami_id" {
  description = "ID of the Amazon Image to use (leave empty to use the latest Ubuntu)"
  default     = ""
}

variable "base64_vpn_server_config" {
  description = "VPN server configuration encoded in base64"
  type        = string
}

variable "application_name" {
  description = "Name of the application"
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
  type        = string
}

variable "allow_ssh" {
  description = "Allow inbound ssh"
  type        = bool
  default     = false
}
