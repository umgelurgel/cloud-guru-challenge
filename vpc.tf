# VPC config
resource "aws_vpc" "etl_vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "etl-vpc"
  }
}

resource "aws_internet_gateway" "etl_igw" {
  vpc_id = aws_vpc.etl_vpc.id

  tags = {
    Name = "etl-igw"
  }
}

data "aws_security_group" "etl_default_sg" {
  vpc_id = aws_vpc.etl_vpc.id
  name   = "default"
}

# Subnets
data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "etl_public_a" {
  vpc_id            = aws_vpc.etl_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "etl-public-a"
  }
}

resource "aws_subnet" "etl_private_a" {
  vpc_id            = aws_vpc.etl_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "etl-private-a"
  }
}

resource "aws_subnet" "etl_private_b" {
  vpc_id            = aws_vpc.etl_vpc.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "etl-private-b"
  }
}

# NAT 
resource "aws_eip" "etl_nat_gw" {
  vpc = true
}

resource "aws_nat_gateway" "etl_nat_gw" {
  allocation_id = aws_eip.etl_nat_gw.id
  subnet_id     = aws_subnet.etl_public_a.id
}

# VPC Route tables
resource "aws_route_table" "etl_private_route_table" {
  vpc_id = aws_vpc.etl_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.etl_nat_gw.id
  }

  tags = {
    Name = "etl-private-route-table"
  }
}

resource "aws_route_table_association" "etl_private_subnet_a_route_table" {
  subnet_id      = aws_subnet.etl_private_a.id
  route_table_id = aws_route_table.etl_private_route_table.id
}

resource "aws_route_table_association" "etl_private_subnet_b_route_table" {
  subnet_id      = aws_subnet.etl_private_b.id
  route_table_id = aws_route_table.etl_private_route_table.id
}

resource "aws_route_table" "etl_public_route_table" {
  vpc_id = aws_vpc.etl_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.etl_igw.id
  }

  tags = {
    Name = "etl-public-route-table"
  }
}

resource "aws_route_table_association" "etl_public_subnet_a_route_table" {
  subnet_id      = aws_subnet.etl_public_a.id
  route_table_id = aws_route_table.etl_public_route_table.id
}
