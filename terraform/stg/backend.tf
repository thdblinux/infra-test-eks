terraform {
  backend "s3" {
    bucket = "devopsthlinux"
    key    = "terraform.tfstate"
    region = "us-east-1"
  }
}