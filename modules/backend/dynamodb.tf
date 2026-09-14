# Tabela DynamoDB para locking do state remoto
# Já não é mais necessário, pois o uso do DynamoDB para locking foi depreciado.
# O Terragrunt agora utiliza um arquivo de lock local (use_lockfile = true)
# para gerenciar o estado remoto.

#resource "aws_dynamodb_table" "locks" {
#  name         = "terraform-locks"
#  billing_mode = "PAY_PER_REQUEST"
#  hash_key     = "LockID"
#  attribute {
#    name = "LockID"
#    type = "S"
#  }
#  tags = {
#    team = "fiap"
#  }
#}