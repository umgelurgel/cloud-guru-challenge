variable "profile" {
  type    = string
  default = "default"
}

variable "region-primary" {
  type    = string
  default = "us-east-1"
}

variable "rds-username" {
  type = string
}

variable "rds-password" {
  type = string
}

variable "notification-email" {
  type = string
}
