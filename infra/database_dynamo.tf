//DynamoDB 
resource "aws_dynamodb_table" "seats" {
  name         = "${var.project_name}-seats"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "showtime_id"
  range_key    = "seat_id"

  attribute {
    name = "showtime_id"
    type = "S"
  }

  attribute {
    name = "seat_id"
    type = "S"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.main.arn
  }

  tags = {
    Name = "${var.project_name}-seats-table"
  }
}