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
  source = "../../modules/root-test"
}

inputs = {

  env             = "test"
  
  #vpc insputs
  vpc_cidr        = "10.0.0.0/16"
  public_subnets  = ["10.0.1.0/24", "10.0.3.0/24"]
  private_subnets = ["10.0.2.0/24", "10.0.4.0/24"]
  azs = ["us-east-1a", "us-east-1b"]

  #EKS
  cluster_name = "toggle-cluster"
  cluster_version = 1.36
}

