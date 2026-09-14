variable "private_subnet_ids" {
  type = list(string)
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "env" {
  type = string
}

variable "db_username" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "db_engine" {
  type    = string
  default = "postgres"
}
variable "db_engine_version" {
  type    = string
  default = "16.4"
}

variable "db_instance_class" {
  type    = string
  default = "db.t3.micro"
}
variable "db_allocated_storage" {
  type    = number
  default = 20

}