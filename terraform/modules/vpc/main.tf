# ============================================================
# Module: VPC
# Creates VPC, subnets, IGW, NAT GW, route tables
# ============================================================

data "aws_availability_zones" "available" {
  state = "available"
}

# ─── VPC ────────────────────────────────────────────────────
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.common_tags, {
    Name                                          = "${var.project_name}-vpc"
    "kubernetes.io/cluster/${var.project_name}"   = "shared"
  })
}

# ─── Public Subnets ─────────────────────────────────────────
resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = merge(var.common_tags, {
    Name                                          = "${var.project_name}-public-${count.index + 1}"
    "kubernetes.io/cluster/${var.project_name}"   = "shared"
    "kubernetes.io/role/elb"                      = "1"
  })
}

# ─── Private Subnets ────────────────────────────────────────
resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = merge(var.common_tags, {
    Name                                          = "${var.project_name}-private-${count.index + 1}"
    "kubernetes.io/cluster/${var.project_name}"   = "shared"
    "kubernetes.io/role/internal-elb"             = "1"
  })
}

# ─── Internet Gateway ───────────────────────────────────────
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.common_tags, { Name = "${var.project_name}-igw" })
}

# ─── Elastic IP for NAT ─────────────────────────────────────
resource "aws_eip" "nat" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.main]

  tags = merge(var.common_tags, { Name = "${var.project_name}-nat-eip" })
}

# ─── NAT Gateway ────────────────────────────────────────────
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id
  depends_on    = [aws_internet_gateway.main]

  tags = merge(var.common_tags, { Name = "${var.project_name}-nat" })
}

# ─── Route Tables ───────────────────────────────────────────
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(var.common_tags, { Name = "${var.project_name}-rt-public" })
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = merge(var.common_tags, { Name = "${var.project_name}-rt-private" })
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
