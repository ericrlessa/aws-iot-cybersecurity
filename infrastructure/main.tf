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
  bucket_vpc_flow_logs_arn = var.bucket_vpc_flow_logs_arn
  bucket_vpc_flow_logs_name = var.bucket_vpc_flow_logs_name
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

module "mosquito-1" {
  source = "./modules/mosquito"
  depends_on = [ module.vpc, module.elasti_search, module.loadbalance, time_sleep.wait_for_elasticsearch, time_sleep.wait_for_kibana ]
  instance_name = "mosquitto-1"
  key_name = var.key_name
  elasticsearch_ip = module.elasti_search.elasticsearch_private_ip
  kibana_ip = module.kibana.kibana_private_ip
  subnet_id = module.vpc.private_subnet_ids[1]
  vpc_id = module.vpc.vpc_id
  target_group = module.loadbalance.target_group_arn
}

module "mosquito-2" {
  source = "./modules/mosquito"
  depends_on = [ module.vpc, module.elasti_search, module.loadbalance, time_sleep.wait_for_elasticsearch, time_sleep.wait_for_kibana ]
  instance_name = "mosquitto-2"
  key_name = var.key_name
  elasticsearch_ip = module.elasti_search.elasticsearch_private_ip
  kibana_ip = module.kibana.kibana_private_ip
  subnet_id = module.vpc.private_subnet_ids[1]
  vpc_id = module.vpc.vpc_id
  target_group = module.loadbalance.target_group_arn
}


module "loadbalance" {
  source = "./modules/loadbalance"
  depends_on = [ module.vpc ]
  vpc_id = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids 
}

# Reference the time_sleep from the module
resource "time_sleep" "wait_for_elasticsearch" {
  depends_on = [module.elasti_search]
  create_duration = "140s"
}

resource "time_sleep" "wait_for_kibana" {
  depends_on = [module.kibana]
  create_duration = "10s"
}