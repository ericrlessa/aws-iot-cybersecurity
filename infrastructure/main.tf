provider "aws" {
  region = var.region

  default_tags {
    tags = {
      project = "IOT"
    }
  }
}

terraform {
  backend "s3" {}
}

module "vpc" {
  source = "./modules/vpc"
  region = var.region
}

module "thing" {
  source = "./modules/thing"
  region = var.region
}