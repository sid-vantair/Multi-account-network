# Provider configuration for the source AWS account
provider "aws" {
  region = "us-east-1"
  profile = "552630710301_AWSAdministratorAccess"
}

# Data source for the ID of the destination AWS account
data "aws_caller_identity" "destination" {
  provider = aws.destination
}

# Provider configuration for the destination AWS account
provider "aws" {
  region = "us-east-1"
  alias = "destination"
  profile = "114931343665_AWSAdministratorAccess"
}

# Resource to enable VPC sharing for the source VPC
resource "aws_ram_resource_share" "vpc_share" {
  name = "source_vpc_share"
  allow_external_principals = true
  tags = {
    Name = "source_vpc_share"
  }
}

resource "aws_ram_principal_association" "sender_invite" {
  principal          = "114931343665"
  resource_share_arn = aws_ram_resource_share.vpc_share.arn
}

resource "aws_ram_resource_share_accepter" "receiver_accept" {
  provider  = aws.destination  
  share_arn = aws_ram_principal_association.sender_invite.resource_share_arn
}

# Resource for the source VPC
resource "aws_vpc" "source" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "source_vpc"
  }
}

# Resource for the source VPC subnet
resource "aws_subnet" "source_subnet" {
  vpc_id = aws_vpc.source.id
  cidr_block = "10.0.1.0/24"
  tags = {
    Name = "source_subnet"
  }
}

# Resource for the source VPC internet gateway
resource "aws_internet_gateway" "source_igw" {
  vpc_id = aws_vpc.source.id
}

# Resource for the source VPC route table
resource "aws_route_table" "source_route_table" {
  vpc_id = aws_vpc.source.id
}

# Resource to associate the source subnet with the source route table
resource "aws_route_table_association" "source_subnet_association" {
  subnet_id = aws_subnet.source_subnet.id
  route_table_id = aws_route_table.source_route_table.id
  depends_on = [aws_internet_gateway.source_igw]
}

# Resource to create an internet route in the source route table
resource "aws_route" "internet_route" {
  route_table_id = aws_route_table.source_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.source_igw.id
}
