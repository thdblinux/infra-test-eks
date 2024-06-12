resource "aws_vpc" "vpc" {
  cidr_block                       = "10.0.0.0/16"
  assign_generated_ipv6_cidr_block = true
  instance_tenancy                 = "default"
  enable_dns_support               = true
  enable_dns_hostnames             = true
  tags = {
    Name = "terraform-aws-vpc"
  }
}

resource "aws_subnet" "pubsub" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "th_pubsub"
  }
}

resource "aws_subnet" "privsub" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"
  tags = {
    Name = "th_privsub"
  }
}


resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.vpc.id
}

resource "aws_route_table" "rt_pub" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

resource "aws_route_table" "rt_priv" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat_gateway.id
  }
}

resource "aws_route_table_association" "route_pub" {
  subnet_id      = aws_subnet.pubsub.id
  route_table_id = aws_route_table.rt_pub.id
}

resource "aws_route_table_association" "route_priv" {
  subnet_id      = aws_subnet.privsub.id
  route_table_id = aws_route_table.rt_priv.id
}

resource "aws_nat_gateway" "nat_gateway" {
  subnet_id     = aws_subnet.pubsub.id

  tags = {
    Name = "nat-gateway"
  }
}