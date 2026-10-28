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
}

resource "aws_lambda_function" "init_db" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "cine-init-db"
  role             = aws_iam_role.lambda_init_db.arn
  handler          = "init_db.lambda_handler"
  runtime          = "python3.11"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  layers           = [aws_lambda_layer_version.psycopg2_layer.arn]
}

resource "aws_lambda_function" "get_billboard" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "cine-get-billboard"
  role             = aws_iam_role.lambda_get_billboard.arn
  handler          = "get_billboard.lambda_handler"
  runtime          = "python3.11"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  layers           = [aws_lambda_layer_version.psycopg2_layer.arn]
}

resource "aws_lambda_function" "book_seat" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "cine-book-seat"
  role             = aws_iam_role.lambda_book_seat.arn
  handler          = "book_seat.lambda_handler"
  runtime          = "python3.11"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
}

resource "aws_lambda_function" "process_payment" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "cine-process-payment"
  role             = aws_iam_role.lambda_process_payment.arn
  handler          = "process_payment.lambda_handler"
  runtime          = "python3.11"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  layers           = [aws_lambda_layer_version.psycopg2_layer.arn]
}