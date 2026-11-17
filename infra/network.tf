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

# Grupos de Seguridad Internos
resource "aws_security_group" "lambda_vpc_sg" {
  name        = "${var.project_name}-lambda-vpc-sg"
  description = "Security group para las funciones Lambda dentro de la VPC"
  vpc_id      = aws_vpc.main.id

  egress {
    description = "Permitir trafico saliente hacia los endpoints y red interna"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-lambda-vpc-sg"
    Environment = var.environment
  }
}

resource "aws_security_group" "vpce_sg" {
  name        = "${var.project_name}-vpce-sg"
  description = "Security group para los VPC Endpoints de interfaz"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Permitir HTTPS hacia los endpoints desde las Lambdas de la VPC"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda_vpc_sg.id]
  }

  tags = {
    Name        = "${var.project_name}-vpce-sg"
    Environment = var.environment
  }
}

resource "aws_security_group" "rds_proxy_sg" {
  name        = "${var.project_name}-rds-proxy-sg"
  description = "Security group para el proxy de bases de datos"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Permitir PostgreSQL desde las Lambdas de la VPC"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda_vpc_sg.id]
  }

  tags = {
    Name        = "${var.project_name}-rds-proxy-sg"
    Environment = var.environment
  }
}

# Gateway VPC Endpoints
resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]

  tags = { Name = "${var.project_name}-dynamodb-vpce" }
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]

  tags = { Name = "${var.project_name}-s3-vpce" }
}

# Interface VPC Endpoints
resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.privada_az1.id, aws_subnet.privada_az2.id]
  security_group_ids  = [aws_security_group.vpce_sg.id]
  private_dns_enabled = true

  tags = { Name = "${var.project_name}-secretsmanager-vpce" }
}

resource "aws_vpc_endpoint" "sns" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.sns"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.privada_az1.id, aws_subnet.privada_az2.id]
  security_group_ids  = [aws_security_group.vpce_sg.id]
  private_dns_enabled = true

  tags = { Name = "${var.project_name}-sns-vpce" }
}

resource "aws_vpc_endpoint" "kms" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.kms"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.privada_az1.id, aws_subnet.privada_az2.id]
  security_group_ids  = [aws_security_group.vpce_sg.id]
  private_dns_enabled = true

  tags = { Name = "${var.project_name}-kms-vpce" }
}