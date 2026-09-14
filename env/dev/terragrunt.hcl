remote_state {
  backend = "s3"
  config = {
    bucket = "challenge3-terraform-state"
    key    = "${path_relative_to_include()}/terraform.tfstate"
    region = "us-east-1"
    //dynamodb_table = "terraform-locks" -> mudança feita pois esta depreciados o uso do dynamodb como lock
    use_lockfile = true
    encrypt        = true
  }
}
terraform {
  source = "../../modules/root"
}

inputs = {

  env             = "dev"
  
  #vpc insputs
  vpc_cidr        = "10.0.0.0/16"
  public_subnets  = ["10.0.1.0/24", "10.0.3.0/24"]
  private_subnets = ["10.0.2.0/24", "10.0.4.0/24"]
  azs = ["us-east-1a", "us-east-1b"]

  #RDS
  rds_databases = ["auth","target","flag"]
  db_username = "teste"
  db_password = "123456678"
  instance_class = "db.t3.micro"
  engine_version = "16.10"

  #dynamodb_table
  dynamodb_key = "event_id"

  #SQS
  name_sqs = "toggle-master-sqs"

  #EKS
  cluster_name = "toggle-cluster"
  cluster_version = 1.36

  #ECR
  aws_oidc_provider_arn = get_env("AWS_OIDC_PROVIDER_ARN")
  repositories = ["toggle-master/analytics-service","toggle-master/auth-service","toggle-master/evaluation-service", "toggle-master/flag-service", "toggle-master/targeting-service"]
}