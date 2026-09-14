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
  source = "../../modules/root-prod"
}

inputs = {

  env             = "prod"
  
  #vpc insputs
  vpc_cidr        = "10.0.0.0/16"
  public_subnets  = ["10.0.1.0/24", "10.0.3.0/24"]
  private_subnets = ["10.0.2.0/24", "10.0.4.0/24"]
  azs = ["us-east-1a", "us-east-1b"]


  
  #rds inputs
  rds_databases = ["auth-service","target-service","flag-service"]
  db_username = "teste"
  db_password = "123456678"
  instance_class = "db.t3.micro"
  engine_version = "16.10"

}