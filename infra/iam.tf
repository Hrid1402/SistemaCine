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
