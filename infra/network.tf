# VPC Aislada
resource "aws_vpc" "main" {
    cidr_block           = "10.0.0.0/16"
    enable_dns_support   = true
    enable_dns_hostnames = true

    tags = {
        Name        = "${var.project_name}-vpc"
        Environment = var.environment
        Project     = var.project_name
    }
}

# Subredes Privadas
resource "aws_subnet" "privada_az1" {
    vpc_id            = aws_vpc.main.id
    cidr_block        = "10.0.1.0/24"
    availability_zone = "${var.aws_region}a"

    tags = {
        Name        = "${var.project_name}-privada-az1"
        Environment = var.environment
        Project     = var.project_name
    }
}

resource "aws_subnet" "privada_az2" {
    vpc_id            = aws_vpc.main.id
    cidr_block        = "10.0.2.0/24"
    availability_zone = "${var.aws_region}b"

    tags = {
        Name        = "${var.project_name}-privada-az2"
        Environment = var.environment
        Project     = var.project_name
    }
}

# Tabla de Rutas Aislada
resource "aws_route_table" "private" {
    vpc_id = aws_vpc.main.id
    tags = {
        Name        = "${var.project_name}-private-rt"
        Environment = var.environment
        Project     = var.project_name
    }
}

resource "aws_route_table_association" "private_az1" {
    subnet_id      = aws_subnet.privada_az1.id
    route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_az2" {
    subnet_id      = aws_subnet.privada_az2.id
    route_table_id = aws_route_table.private.id
}