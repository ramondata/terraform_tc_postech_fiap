# Ambiente da conta pessoal; nao reutiliza LabRole nem o state do Academy.
terraform {
  source = "../../modules/personal"
}
remote_state {
  backend = "s3"
  config = {
    bucket       = get_env("PERSONAL_STATE_BUCKET")
    key          = "personal/toggle-master/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
inputs = {
  account_id         = "172346499417"
  region             = "us-east-1"
  env                = "dev"
  cluster_name       = "toggle-cluster"
  node_count         = 3
  eks_version        = get_env("PERSONAL_EKS_VERSION")
  rds_engine_version = get_env("PERSONAL_RDS_VERSION")
}
# db_password e fornecida por TF_VAR_db_password, fora do checkout.
