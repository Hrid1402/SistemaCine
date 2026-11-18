# Empaquetado de los scripts
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../backend/functions"
  output_path = "${path.module}/files/lambda_functions.zip"
}

resource "aws_lambda_layer_version" "psycopg2_layer" {
  filename            = "${path.module}/../backend/layers/psycopg2_layer.zip"
  layer_name          = "psycopg2-python311"
  compatible_runtimes = ["python3.11"]
  source_code_hash    = filebase64sha256("${path.module}/../backend/layers/psycopg2_layer.zip")
}

resource "aws_lambda_function" "init_db" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "cine-init-db"
  role             = aws_iam_role.lambda_init_db.arn
  handler          = "init_db.lambda_handler"
  runtime          = "python3.11"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  layers           = [aws_lambda_layer_version.psycopg2_layer.arn]
  timeout          = 60
  memory_size      = 256

  # Integración con la Red Privada (VPC)
  vpc_config {
    subnet_ids         = [aws_subnet.privada_az1.id, aws_subnet.privada_az2.id]
    security_group_ids = [aws_security_group.lambda_vpc_sg.id]
  }

  environment {
    variables = {
      DB_SECRET_NAME = aws_secretsmanager_secret.db_secret.name
      DB_HOST        = aws_db_proxy.postgres_proxy.endpoint
    }
  }
}

# Inicializacion automatica de la base de datos al desplegar con Terraform
resource "aws_lambda_invocation" "init_db" {
  function_name = aws_lambda_function.init_db.function_name
  input         = jsonencode({})

  triggers = {
    redeployment = data.archive_file.lambda_zip.output_base64sha256
  }

  depends_on = [
    aws_lambda_function.init_db,
    aws_db_instance.postgres,
    aws_db_proxy.postgres_proxy,
    aws_db_proxy_target.proxy_target,
    aws_secretsmanager_secret_version.db_secret_val
  ]
}

resource "aws_lambda_function" "get_billboard" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "cine-get-billboard"
  role             = aws_iam_role.lambda_get_billboard.arn
  handler          = "get_billboard.lambda_handler"
  runtime          = "python3.11"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  layers           = [aws_lambda_layer_version.psycopg2_layer.arn]
  timeout          = 15
  memory_size      = 256

  # Integración con la Red Privada (VPC)
  vpc_config {
    subnet_ids         = [aws_subnet.privada_az1.id, aws_subnet.privada_az2.id]
    security_group_ids = [aws_security_group.lambda_vpc_sg.id]
  }

  environment {
    variables = {
      DB_SECRET_NAME      = aws_secretsmanager_secret.db_secret.name
      DB_HOST             = aws_db_proxy.postgres_proxy.endpoint
      S3_BUCKET_NAME      = aws_s3_bucket.posters.id
      DYNAMODB_TABLE_NAME = aws_dynamodb_table.seats.name
      CLOUDFRONT_DOMAIN   = aws_cloudfront_distribution.cine_cdn.domain_name
    }
  }
}

resource "aws_lambda_function" "book_seat" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "cine-book-seat"
  role             = aws_iam_role.lambda_book_seat.arn
  handler          = "book_seat.lambda_handler"
  runtime          = "python3.11"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  layers           = [aws_lambda_layer_version.psycopg2_layer.arn]
  timeout          = 15
  memory_size      = 256

  environment {
    variables = {
      DYNAMODB_TABLE_NAME = aws_dynamodb_table.seats.name
      DB_SECRET_NAME      = aws_secretsmanager_secret.db_secret.name
      SQS_QUEUE_URL       = aws_sqs_queue.compras.id
    }
  }
}

resource "aws_lambda_function" "process_payment" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "cine-process-payment"
  role             = aws_iam_role.lambda_process_payment.arn
  handler          = "process_payment.lambda_handler"
  runtime          = "python3.11"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  layers           = [aws_lambda_layer_version.psycopg2_layer.arn]
  timeout          = 15
  memory_size      = 256

  # Integración con la Red Privada (VPC)
  vpc_config {
    subnet_ids         = [aws_subnet.privada_az1.id, aws_subnet.privada_az2.id]
    security_group_ids = [aws_security_group.lambda_vpc_sg.id]
  }

  environment {
    variables = {
      DB_SECRET_NAME      = aws_secretsmanager_secret.db_secret.name
      DB_HOST             = aws_db_proxy.postgres_proxy.endpoint
      DYNAMODB_TABLE_NAME = aws_dynamodb_table.seats.name
      SNS_TOPIC_ARN       = aws_sns_topic.alertas.arn
    }
  }
}

# Función Lambda para Administración (manage_admin)
resource "aws_lambda_function" "manage_admin" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "cine-manage-admin"
  role             = aws_iam_role.lambda_manage_admin.arn
  handler          = "manage_admin.lambda_handler"
  runtime          = "python3.11"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  layers           = [aws_lambda_layer_version.psycopg2_layer.arn]
  timeout          = 15
  memory_size      = 256

  # Integración con la Red Privada (VPC)
  vpc_config {
    subnet_ids         = [aws_subnet.privada_az1.id, aws_subnet.privada_az2.id]
    security_group_ids = [aws_security_group.lambda_vpc_sg.id]
  }

  environment {
    variables = {
      DB_SECRET_NAME = aws_secretsmanager_secret.db_secret.name
      DB_HOST        = aws_db_proxy.postgres_proxy.endpoint
    }
  }
}

resource "aws_lambda_event_source_mapping" "sqs_compras_to_payment" {
  event_source_arn = aws_sqs_queue.compras.arn
  function_name    = aws_lambda_function.process_payment.arn
  batch_size       = 10
  enabled          = true
}