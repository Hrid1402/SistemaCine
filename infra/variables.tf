variable "aws_profile" {
  type = string
}

variable "aws_region" {
  type    = string
  default = "sa-east-1"
}

variable "project_name" {
  type    = string
  default = "cinespot-pmv"
}

variable "s3_bucket_name" {
  type    = string
  default = "cinespot-pmv-s3"
}

variable "db_username" {
  type    = string
  default = "cinespot_admin"
}

variable "db_password" {
  type      = string
  sensitive = true
}