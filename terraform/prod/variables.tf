variable "vpc_cidr" {}
variable "private_subnet_cidr_blocks" {}
variable "public_subnet_cidr_blocks" {}
variable "azs" {}
variable "region" {}
variable "cluster_name" { default = "matrix-prod" }
variable "cluster_version" { default = "1.28" }