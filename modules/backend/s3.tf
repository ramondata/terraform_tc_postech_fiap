# Bucket S3 para armazenar o state remoto (compartilhado)
resource "aws_s3_bucket" "state" {
  bucket        = "challenge3-terraform-state"
  force_destroy = true
  tags = {
    team = "fiap"
  }
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

output "bucket_name" {
  value = aws_s3_bucket.state.arn
}