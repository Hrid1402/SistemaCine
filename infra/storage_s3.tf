//S3 Bucket
resource "aws_s3_bucket" "posters" {
  bucket        = var.s3_bucket_name
  force_destroy = true

  tags = {
    Name = "${var.project_name}-posters-bucket"
  }
}
//S3 Bucket Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "posters_encryption" {
  bucket = aws_s3_bucket.posters.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.main.key_id
      sse_algorithm     = "aws:kms"
    }
  }
}
//S3 Bucket Object
resource "aws_s3_object" "sample_poster" {
  for_each     = fileset("${path.module}/../assets/posters", "*")
  bucket       = aws_s3_bucket.posters.id
  key          = "posters/${each.value}"
  source       = "${path.module}/../assets/posters/${each.value}"
  content_type = endswith(each.value, ".png") ? "image/png" : "image/jpeg"
  etag         = filemd5("${path.module}/../assets/posters/${each.value}")
}