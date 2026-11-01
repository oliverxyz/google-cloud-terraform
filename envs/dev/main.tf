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

locals {
  service_members = module.iam.service_account_members
}

module "secrets" {
  source = "../../modules/secrets"

  environment = var.environment
  region      = var.region

  accessors = {
    api-db-password         = { secret = "db-password", member = local.service_members["api"] }
    worker-db-password      = { secret = "db-password", member = local.service_members["worker"] }
    dlq-handler-db-password = { secret = "db-password", member = local.service_members["dlq-handler"] }
    reporter-db-password    = { secret = "db-password", member = local.service_members["reporter"] }
    api-api-token           = { secret = "api-token", member = local.service_members["api"] }
  }
}

module "storage" {
  source = "../../modules/storage"

  project_id  = var.project_id
  environment = var.environment
  region      = var.region

  grants = {
    worker-creator   = { role = "roles/storage.objectCreator", member = local.service_members["worker"] }
    reporter-viewer  = { role = "roles/storage.objectViewer", member = local.service_members["reporter"] }
    reporter-creator = { role = "roles/storage.objectCreator", member = local.service_members["reporter"] }
  }
}

module "queue" {
  source = "../../modules/queue"

  project_id  = var.project_id
  environment = var.environment
  region      = var.region

  publisher_member              = local.service_members["api"]
  subscriber_member             = local.service_members["worker"]
  dead_letter_subscriber_member = local.service_members["dlq-handler"]
}
