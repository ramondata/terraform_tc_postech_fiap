# varables for the root module
variable "env" {
  type = string
}

# Variables for the vpc module
variable "vpc_cidr" {
  type = string
}
variable "public_subnets" {
  type = list(string)
}
variable "private_subnets" {
  type = list(string)
}
variable "azs" {
  type = list(string)
}

# Variables for the rds module

variable "db_password" {
  type      = string
  sensitive = true
}

variable "db_username" {
  type = string
}

variable "engine" {
  type    = string
  default = "postgres"
}
variable "engine_version" {
  type    = string
  default = "16.4"
}

variable "instance_class" {
  type    = string
  default = "db.t3.micro"
}
variable "allocated_storage" {
  type    = number
  default = 20

}

# dynamodb variables
variable "dynamodb_key" {
  type = string
}


# Variables for the sqs module
variable "name_sqs" {
  type = string
}



# Variables for the eks module
variable "cluster_version" {
  type    = string
  default = "1.27"
}

variable "cluster_name" {
  type = string
}

variable "node_instance_types" {
  type    = list(string)
  default = ["t3.medium"]
}

variable "desired_size" {
  type    = number
  default = 2
}

variable "min_size" {
  type    = number
  default = 1
}

variable "max_size" {
  type    = number
  default = 3
}