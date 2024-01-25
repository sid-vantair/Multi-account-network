provider "aws" {  
  region  = "us-east-1"  
  alias = "requester"
  # Requester's credentials.
  profile = "552630710301_AWSAdministratorAccess"
}

provider "aws" {
  region  = "us-east-1"  
  alias = "accepter"
  # accepter's credentials.
  profile = "114931343665_AWSAdministratorAccess"
}

resource "aws_vpc" "main" {
  provider = aws.requester
  cidr_block = "10.1.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "PinProd"
  }
}

resource "aws_subnet" "PinProd" {
  provider = aws.requester  
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.1.8.0/24"
  depends_on = [aws_vpc.main]
  tags = {
    Name = "PinProd Subnet"
  }
}

resource "aws_route_table" "PinProd-RT" {
  provider = aws.requester 
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "PinProd Route Table"
  }
}

resource "aws_route" "pinprod-moka1-route" {
  provider = aws.requester 
  route_table_id            = aws_route_table.PinProd-RT.id
  destination_cidr_block    = aws_vpc.peer.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
}


resource "aws_route_table_association" "PinProd_RT_association" {
  provider = aws.requester 
  subnet_id      = aws_subnet.PinProd.id
  route_table_id = aws_route_table.PinProd-RT.id
}

resource "aws_vpc" "peer" {
  provider = aws.accepter  
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "moka1"
  }
}

resource "aws_vpc_ipv4_cidr_block_association" "secondary_cidr1" {
  provider = aws.accepter  
  vpc_id     = aws_vpc.peer.id  
  cidr_block = "100.64.0.0/16"
 
}

resource "aws_vpc_ipv4_cidr_block_association" "secondary_cidr2" {
  provider = aws.accepter  
  cidr_block = "100.65.0.0/16"
  vpc_id     = aws_vpc.peer.id
}

resource "aws_subnet" "EKS-CP-Subnet-1" {
  provider = aws.accepter  
  vpc_id            = aws_vpc.peer.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  depends_on = [aws_vpc.peer]

  tags = {
    Name = "EKS CP Subnet 1"
  }
}

resource "aws_subnet" "EKS-CP-Subnet-2" {
  provider = aws.accepter
  vpc_id            = aws_vpc.peer.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"
  depends_on = [aws_vpc.peer]
  tags = {
    Name = "EKS CP Subnet 2"
  }
}

resource "aws_subnet" "EKS-nodes-subnet" {
  provider = aws.accepter  
  vpc_id            = aws_vpc.peer.id
  cidr_block        = "10.0.8.0/21"
  availability_zone = "us-east-1c"
  depends_on = [aws_vpc.peer]
  tags = {
    Name = "EKS node subnet"
  }
}

resource "aws_subnet" "PODS-CGNat-Subnet1" {
  provider = aws.accepter
  vpc_id            = aws_vpc.peer.id
  cidr_block        = "100.64.0.0/16"
  availability_zone = "us-east-1a"
  depends_on = [aws_vpc_ipv4_cidr_block_association.secondary_cidr1]

  tags = {
    Name = "PODS CGNat Subnet1"
  }
}

resource "aws_subnet" "PODS-CGNat-Subnet2" {
  provider = aws.accepter
  vpc_id            = aws_vpc.peer.id
  cidr_block        = "100.65.0.0/16"
  availability_zone = "us-east-1b"
  depends_on = [aws_vpc_ipv4_cidr_block_association.secondary_cidr2]

  tags = {
    Name = "PODS CGNat Subnet2"
  }
}

resource "aws_route_table" "moka1-RT" {
  provider = aws.accepter 
  vpc_id = aws_vpc.peer.id

  tags = {
    Name = "Moka1 Route Table"
  }
}

resource "aws_route" "moka1-pinprod-route" {
  provider = aws.accepter 
  route_table_id            = aws_route_table.moka1-RT.id
  destination_cidr_block    = aws_vpc.main.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
}


resource "aws_route_table_association" "Moka1_RT_association" {
  provider = aws.accepter 
  subnet_id      = aws_subnet.EKS-nodes-subnet.id
  route_table_id = aws_route_table.moka1-RT.id
}



data "aws_caller_identity" "peer" {
  provider = aws.accepter
}

# Requester's side of the connection.
resource "aws_vpc_peering_connection" "peer" {
  provider = aws.requester
  vpc_id        = aws_vpc.main.id
  peer_vpc_id   = aws_vpc.peer.id
  peer_owner_id = data.aws_caller_identity.peer.account_id
  auto_accept   = false
  tags = {
    Side = "Requester"
  }
}

# Accepter's side of the connection.
resource "aws_vpc_peering_connection_accepter" "peer" {
  provider = aws.accepter
  vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
  auto_accept               = true
  tags = {
    Side = "Accepter"
  }
}

resource "aws_vpc_peering_connection_options" "requester" {
  provider = aws.requester
  # As options can't be set until the connection has been accepted
  # create an explicit dependency on the accepter.
  vpc_peering_connection_id = aws_vpc_peering_connection_accepter.peer.id
  requester {
    allow_remote_vpc_dns_resolution = true
  }
}

resource "aws_vpc_peering_connection_options" "accepter" {
  provider = aws.accepter
  vpc_peering_connection_id = aws_vpc_peering_connection_accepter.peer.id
  accepter {
    allow_remote_vpc_dns_resolution = true
  }
}
