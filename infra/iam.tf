# Rol IAM para la función init_db (Permisos de CloudWatch y lectura de secretos de BD)
resource "aws_iam_role" "lambda_init_db" {
  name = "lambda-init-db-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "init_db_basic" {
  role       = aws_iam_role.lambda_init_db.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "init_db_secrets" {
  role       = aws_iam_role.lambda_init_db.name
  policy_arn = aws_iam_policy.db_secrets_policy.arn
}

# Rol IAM para la función get_billboard
resource "aws_iam_role" "lambda_get_billboard" {
  name = "lambda-get-billboard-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "get_billboard_basic" {
  role       = aws_iam_role.lambda_get_billboard.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "get_billboard_secrets" {
  role       = aws_iam_role.lambda_get_billboard.name
  policy_arn = aws_iam_policy.db_secrets_policy.arn
}

resource "aws_iam_role_policy_attachment" "get_billboard_s3" {
  role       = aws_iam_role.lambda_get_billboard.name
  policy_arn = aws_iam_policy.s3_read_policy.arn
}

resource "aws_iam_role_policy_attachment" "get_billboard_dynamo" {
  role       = aws_iam_role.lambda_get_billboard.name
  policy_arn = aws_iam_policy.dynamodb_put_policy.arn
}

# Rol IAM para la función book_seat
resource "aws_iam_role" "lambda_book_seat" {
  name = "lambda-book-seat-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "book_seat_basic" {
  role       = aws_iam_role.lambda_book_seat.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "book_seat_dynamo" {
  role       = aws_iam_role.lambda_book_seat.name
  policy_arn = aws_iam_policy.dynamodb_put_policy.arn
}

resource "aws_iam_role_policy_attachment" "book_seat_secrets" {
  role       = aws_iam_role.lambda_book_seat.name
  policy_arn = aws_iam_policy.db_secrets_policy.arn
}

# Rol IAM para la función process_payment
resource "aws_iam_role" "lambda_process_payment" {
  name = "lambda-process-payment-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "process_payment_basic" {
  role       = aws_iam_role.lambda_process_payment.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "process_payment_secrets" {
  role       = aws_iam_role.lambda_process_payment.name
  policy_arn = aws_iam_policy.db_secrets_policy.arn
}

resource "aws_iam_role_policy_attachment" "process_payment_dynamo" {
  role       = aws_iam_role.lambda_process_payment.name
  policy_arn = aws_iam_policy.dynamodb_put_policy.arn
}

# --- NUEVO: Rol IAM para la función manage_admin ---
resource "aws_iam_role" "lambda_manage_admin" {
  name = "lambda-manage-admin-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "manage_admin_basic" {
  role       = aws_iam_role.lambda_manage_admin.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "manage_admin_secrets" {
  role       = aws_iam_role.lambda_manage_admin.name
  policy_arn = aws_iam_policy.db_secrets_policy.arn
}

# Política compartida para DynamoDB (Crear, consultar y actualizar reservas)
resource "aws_iam_policy" "dynamodb_put_policy" {
  name = "lambda-dynamodb-put-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["dynamodb:PutItem", "dynamodb:GetItem", "dynamodb:UpdateItem", "dynamodb:Query"]
        Resource = aws_dynamodb_table.seats.arn
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:GenerateDataKey"]
        Resource = aws_kms_key.main.arn
      }
    ]
  })
}
#Políticas para SQS y SNS
resource "aws_iam_policy" "sqs_send_policy" {
  name        = "${var.project_name}-sqs-send-policy"
  description = "Allows book_seat Lambda to send messages to the purchases queue"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["sqs:SendMessage", "sqs:GetQueueAttributes"]
        Resource = aws_sqs_queue.compras.arn
      },
      {
        Effect   = "Allow"
        Action   = ["kms:GenerateDataKey", "kms:Decrypt"]
        Resource = aws_kms_key.main.arn
      }
    ]
  })
}
resource "aws_iam_role_policy_attachment" "book_seat_sqs" {
  role       = aws_iam_role.lambda_book_seat.name
  policy_arn = aws_iam_policy.sqs_send_policy.arn
}

resource "aws_iam_policy" "payment_sqs_sns_policy" {
  name        = "${var.project_name}-payment-sqs-sns-policy"
  description = "Allows process_payment Lambda to consume purchases queue and publish to SNS"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
        Resource = aws_sqs_queue.compras.arn
      },
      {
        Effect   = "Allow"
        Action   = ["sns:Publish"]
        Resource = aws_sns_topic.alertas.arn
      },
      {
        Effect   = "Allow"
        Action   = ["kms:GenerateDataKey", "kms:Decrypt"]
        Resource = aws_kms_key.main.arn
      }
    ]
  })
}
resource "aws_iam_role_policy_attachment" "process_payment_sqs_sns" {
  role       = aws_iam_role.lambda_process_payment.name
  policy_arn = aws_iam_policy.payment_sqs_sns_policy.arn
}

# Política compartida para lectura de Secrets Manager y descifrado KMS
resource "aws_iam_policy" "db_secrets_policy" {
  name        = "${var.project_name}-db-secrets-policy"
  description = "Permite a las Lambdas leer credenciales de Secrets Manager y descifrar con KMS"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = aws_secretsmanager_secret.db_secret.arn
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:DescribeKey"]
        Resource = aws_kms_key.main.arn
      }
    ]
  })
}

# Política para lectura de posters en S3 y descifrado KMS
resource "aws_iam_policy" "s3_read_policy" {
  name        = "${var.project_name}-s3-read-policy"
  description = "Permite a la Lambda leer posters en S3 y descifrar con KMS"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "${aws_s3_bucket.posters.arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt"]
        Resource = aws_kms_key.main.arn
      }
    ]
  })
}

//AWS Backup IAM Role
resource "aws_iam_role" "aws_backup" {
  name = "${var.project_name}-aws-backup-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "backup.amazonaws.com" }
    }]
  })
}
resource "aws_iam_role_policy_attachment" "aws_backup_service" {
  role       = aws_iam_role.aws_backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}
resource "aws_iam_role_policy_attachment" "aws_backup_restore" {
  role       = aws_iam_role.aws_backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
}

# Rol IAM para RDS Proxy
resource "aws_iam_role" "rds_proxy_role" {
  name = "${var.project_name}-rds-proxy-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "rds.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "rds_proxy_policy" {
  name = "${var.project_name}-rds-proxy-policy"
  role = aws_iam_role.rds_proxy_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
        Resource = [aws_secretsmanager_secret.db_secret.arn]
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt"]
        Resource = [aws_kms_key.main.arn]
      }
    ]
  })
}

# Adjuntar permisos de red VPC a las Lambdas dentro de la VPC
resource "aws_iam_role_policy_attachment" "init_db_vpc" {
  role       = aws_iam_role.lambda_init_db.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "get_billboard_vpc" {
  role       = aws_iam_role.lambda_get_billboard.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "process_payment_vpc" {
  role       = aws_iam_role.lambda_process_payment.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "manage_admin_vpc" {
  role       = aws_iam_role.lambda_manage_admin.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}