resource "aws_vpc" "that" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  
  tags = {
    Name = "lab-vpc"
  }
}

locals {
  private_subnet_cidr = ["10.0.1.0/24", "10.0.3.0/24", "10.0.5.0/24"]
  public_subnet_cidr  = ["10.0.2.0/24", "10.0.4.0/24", "10.0.6.0/24"]
}

data "aws_availability_zones" "available" {
  state = "available"
}

# Public Subnets
resource "aws_subnet" "public" {
  count                   = length(local.public_subnet_cidr)
  vpc_id                  = aws_vpc.that.id
  cidr_block              = local.public_subnet_cidr[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "public-${count.index}"
    Type = "public"
  }
}

# Private Subnets
resource "aws_subnet" "private" {
  count                   = length(local.private_subnet_cidr)
  vpc_id                  = aws_vpc.that.id
  cidr_block              = local.private_subnet_cidr[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name = "private-${count.index}"
    Type = "private"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "that" {
  vpc_id = aws_vpc.that.id
  tags = {
    Name = "lab-igw"
  }
}

# Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"
  
  tags = {
    Name = "nat-eip"
  }
}

# NAT Gateway (single for cost optimization in lab)
resource "aws_nat_gateway" "that" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id  # Deploy NAT in first public subnet
  
  tags = {
    Name = "lab-nat-gateway"
  }
  
  # Ensure NAT Gateway is created after IGW
  depends_on = [aws_internet_gateway.that]
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.that.id
  
  tags = {
    Name = "public-rt"
  }
}

# Public Route Table Associations
resource "aws_route_table_association" "public_assoc" {
  count          = length(local.public_subnet_cidr)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Public Route to Internet
resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.that.id
}

# Private Route Table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.that.id
  
  tags = {
    Name = "private-rt"
  }
}

# Private Route to NAT Gateway
resource "aws_route" "private_nat" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.that.id
}

# Private Route Table Associations (one per private subnet)
resource "aws_route_table_association" "private_assoc" {
  count          = length(local.private_subnet_cidr)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}


############### FLOW LOG VPC ######################

resource "aws_flow_log" "vpc_flow_log" {
  vpc_id = aws_vpc.that.id

  log_destination      = var.bucket_vpc_flow_logs_arn
  log_destination_type = "s3"

  traffic_type = "ALL" # or ACCEPT / REJECT

  tags = {
    Name = "vpc-flow-logs"
  }
}

resource "aws_s3_bucket_policy" "flow_logs_policy" {
  bucket = var.bucket_vpc_flow_logs_name
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
        Action = "s3:PutObject"
        Resource = "${var.bucket_vpc_flow_logs_arn}/*"
      }
    ]
  })
}