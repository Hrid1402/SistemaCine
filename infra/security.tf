//Key Management Service
resource "aws_kms_key" "main" {
  description             = "Llave KMS para cifrar RDS, DynamoDB, S3 y Secrets Manager"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Name = "${var.project_name}-kms-key"
  }
}

resource "aws_kms_alias" "main" {
  name          = "alias/${var.project_name}-kms-key"
  target_key_id = aws_kms_key.main.key_id
}

//Secrets Manager
resource "aws_secretsmanager_secret" "db_secret" {
  name                    = "${var.project_name}-db-credentials"
  description             = "Credenciales de conexion hacia las bases de datos"
  kms_key_id              = aws_kms_key.main.key_id
  recovery_window_in_days = 0

  tags = {
    Name = "${var.project_name}-db-secret"
  }
}