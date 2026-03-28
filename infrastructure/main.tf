provider "aws" {
  region = var.region

  default_tags {
    tags = {
      project = "IOT"
    }
  }
  
}

terraform {
  required_providers {
    time = {
      source = "hashicorp/time"
      version = ">= 0.9.0"
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

module "elasti_search" {
  source = "./modules/elastic_search"
  depends_on = [ module.vpc ]
  private_subnet_id = module.vpc.private_subnet_ids[0]
  key_name = var.key_name
  region = var.region
  vpc_id = module.vpc.vpc_id
}

module "kibana" {
  source = "./modules/kibana"
  depends_on = [ module.vpc, module.elasti_search, time_sleep.wait_for_elasticsearch ]
  elasticsearch_ip = module.elasti_search.elasticsearch_private_ip
  key_name = var.key_name
  public_subnet_id = module.vpc.public_subnet_ids[0]
  vpc_id = module.vpc.vpc_id
}

module "mosquito" {
  source = "./modules/mosquito"
  depends_on = [ module.vpc, module.elasti_search ]
  key_name = var.key_name
  elasticsearch_ip = module.elasti_search.elasticsearch_private_ip
  public_subnet_id = module.vpc.public_subnet_ids[1]
  vpc_id = module.vpc.vpc_id
}

# Reference the time_sleep from the module
resource "time_sleep" "wait_for_elasticsearch" {
  depends_on = [module.elasti_search]
  create_duration = "60s"
}