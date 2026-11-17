# --- DB Subnet Group ---
resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = [aws_subnet.privada_az1.id, aws_subnet.privada_az2.id]

  tags = { Name = "${var.project_name}-db-subnet-group" }
}

# --- Ajustar Security Group de RDS ---
resource "aws_security_group" "rds_sg" {
  name        = "${var.project_name}-rds-sg"
  description = "Control de acceso a base de datos PostgreSQL"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Permitir PostgreSQL exclusivamente desde el Proxy y Lambdas"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.rds_proxy_sg.id, aws_security_group.lambda_vpc_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-rds-sg" }
}

# --- Instancia RDS Multi-AZ ---
resource "aws_db_instance" "postgres" {
  identifier              = "${var.project_name}-db"
  allocated_storage       = 20
  max_allocated_storage   = 100
  engine                  = "postgres"
  engine_version          = "16"
  instance_class          = "db.t3.micro"
  db_name                 = "cinemadb"
  username                = var.db_username
  password                = var.db_password
  db_subnet_group_name    = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids  = [aws_security_group.rds_sg.id]
  multi_az                = true # Réplica síncrona en la segunda zona (AZ-2)
  publicly_accessible     = false
  skip_final_snapshot     = true
  storage_encrypted       = true
  kms_key_id              = aws_kms_key.main.arn
  backup_retention_period = 7

  tags = { Name = "${var.project_name}-postgres-instance" }
}

# --- Amazon RDS Proxy ---
resource "aws_db_proxy" "postgres_proxy" {
  name                   = "${var.project_name}-rds-proxy"
  debug_logging          = false
  engine_family          = "POSTGRESQL"
  idle_client_timeout    = 1800
  require_tls            = true
  role_arn               = aws_iam_role.rds_proxy_role.arn
  vpc_subnet_ids         = [aws_subnet.privada_az1.id, aws_subnet.privada_az2.id]
  vpc_security_group_ids = [aws_security_group.rds_proxy_sg.id]

  auth {
    auth_scheme = "SECRETS"
    description = "Autenticacion basada en Secrets Manager"
    iam_auth    = "DISABLED"
    secret_arn  = aws_secretsmanager_secret.db_secret.arn
  }

  tags = { Name = "${var.project_name}-rds-proxy" }
}

resource "aws_db_proxy_default_target_group" "proxy_target_group" {
  db_proxy_name = aws_db_proxy.postgres_proxy.name

  connection_pool_config {
    connection_borrow_timeout    = 120
    max_connections_percent      = 100
    max_idle_connections_percent = 50
  }
}

resource "aws_db_proxy_target" "proxy_target" {
  db_proxy_name          = aws_db_proxy.postgres_proxy.name
  target_group_name      = aws_db_proxy_default_target_group.proxy_target_group.name
  db_instance_identifier = lower(aws_db_instance.postgres.identifier)
}

# --- Actualizar Secrets Manager para apuntar al Endpoint del Proxy ---
resource "aws_secretsmanager_secret_version" "db_secret_val" {
  secret_id = aws_secretsmanager_secret.db_secret.id
  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
    engine   = "postgres"
    host     = aws_db_proxy.postgres_proxy.endpoint # Apunta al Proxy y no directamente a la instancia RDS
    port     = 5432
    dbname   = aws_db_instance.postgres.db_name
  })
}