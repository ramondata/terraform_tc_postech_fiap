resource "aws_dynamodb_table" "dynamodb" {
  name         = "${var.env}-dynamodb"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = var.dynamodb_key
  attribute {
    name = var.dynamodb_key
    type = "S"
  }
  tags = {
    team = "fiap"
  }
}