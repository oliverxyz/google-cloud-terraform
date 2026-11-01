module "network" {
  source = "../../modules/network"

  environment     = var.environment
  region          = var.region
  nodes_cidr      = var.network.nodes_cidr
  services_cidr   = var.network.services_cidr
  pods_cidr       = var.network.pods_cidr
  database_cidr   = var.network.database_cidr
  proxy_only_cidr = var.network.proxy_only_cidr
}

module "iam" {
  source = "../../modules/iam"

  project_id  = var.project_id
  environment = var.environment
}
