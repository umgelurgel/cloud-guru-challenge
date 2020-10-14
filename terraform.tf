terraform {
  required_version = ">=0.12.0"
  required_providers {
    aws = ">=3.0.0"
  }
  backend "s3" {
    bucket = "jts-terraform-cloudguru-challenge"
    region = "us-east-1"
    key    = "terraformstatefile"
  }
}
