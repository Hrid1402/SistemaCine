# Rol IAM para la función init_db (Permisos básicos de ejecución en CloudWatch)
resource "aws_iam_role" "lambda_init_db" {
    name = "lambda-init-db-role"
    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
            Action = "sts:AssumeRole"
            Effect = "Allow"
            Principal = { Service = "lambda.amazonaws.com" }
        }]
    })
}

resource "aws_iam_role_policy_attachment" "init_db_basic" {
    role       = aws_iam_role.lambda_init_db.name
    policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Rol IAM para la función get_billboard
resource "aws_iam_role" "lambda_get_billboard" {
    name = "lambda-get-billboard-role"
    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
            Action = "sts:AssumeRole"
            Effect = "Allow"
            Principal = { Service = "lambda.amazonaws.com" }
        }]
    })
}

resource "aws_iam_role_policy_attachment" "get_billboard_basic" {
    role       = aws_iam_role.lambda_get_billboard.name
    policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Rol IAM para la función book_seat
resource "aws_iam_role" "lambda_book_seat" {
    name = "lambda-book-seat-role"
    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
            Action = "sts:AssumeRole"
            Effect = "Allow"
            Principal = { Service = "lambda.amazonaws.com" }
        }]
    })
}

resource "aws_iam_role_policy_attachment" "book_seat_basic" {
    role       = aws_iam_role.lambda_book_seat.name
    policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_policy" "dynamodb_put_policy" {
    name = "lambda-dynamodb-put-policy"
    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
            Effect   = "Allow"
            Action   = ["dynamodb:PutItem", "dynamodb:GetItem"]
            Resource = "arn:aws:dynamodb:*:*:table/CineSeats*"
        }]
    })
}

resource "aws_iam_role_policy_attachment" "book_seat_dynamo" {
    role       = aws_iam_role.lambda_book_seat.name
    policy_arn = aws_iam_policy.dynamodb_put_policy.arn
}

# Rol IAM para la función process_payment
resource "aws_iam_role" "lambda_process_payment" {
    name = "lambda-process-payment-role"
    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
            Action = "sts:AssumeRole"
            Effect = "Allow"
            Principal = { Service = "lambda.amazonaws.com" }
        }]
    })
}

resource "aws_iam_role_policy_attachment" "process_payment_basic" {
    role       = aws_iam_role.lambda_process_payment.name
    policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}