provider "aws" {
  version    = "~> 2.31.0"
  region     = "ca-central-1"
  access_key = var.access_key
  secret_key = var.secret_key
}

provider "random" {
  version = "~> 2.0"
}
