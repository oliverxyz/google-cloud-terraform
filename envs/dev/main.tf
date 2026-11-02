locals {
  service_members = module.iam.service_account_members
  deployer_member = "serviceAccount:deployer-${var.environment}@${var.project_id}.iam.gserviceaccount.com"
}

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

module "secrets" {
  source = "../../modules/secrets"

  environment = var.environment
  region      = var.region

  # Nothing reads db-admin-password: it is for manual administration only.
  accessors = {
    api-db-password         = { secret = "db-password", member = local.service_members["api"] }
    worker-db-password      = { secret = "db-password", member = local.service_members["worker"] }
    dlq-handler-db-password = { secret = "db-password", member = local.service_members["dlq-handler"] }
    reporter-db-password    = { secret = "db-password", member = local.service_members["reporter"] }
    api-api-token           = { secret = "api-token", member = local.service_members["api"] }
  }
}

module "database" {
  source = "../../modules/database"

  project_id               = var.project_id
  environment              = var.environment
  region                   = var.region
  network_id               = module.network.network_id
  subnet_id                = module.network.database_subnet_id
  password_secret_id       = module.secrets.secret_ids["db-password"]
  admin_password_secret_id = module.secrets.secret_ids["db-admin-password"]

  tier              = var.database.tier
  availability_type = var.database.availability_type
  disk_size_gb      = var.database.disk_size_gb
  backups_enabled   = var.database.backups_enabled

  # Passwords are read from the secrets, so their versions have to exist first.
  depends_on = [module.secrets]
}

module "registry" {
  source = "../../modules/registry"

  project_id  = var.project_id
  environment = var.environment
  region      = var.region

  reader_member = module.iam.nodes_service_account_member
  # Created in bootstrap, because GitHub Actions has to outlive the environment.
  writer_member = local.deployer_member
}

module "gke" {
  source = "../../modules/gke"

  environment                 = var.environment
  region                      = var.region
  network_id                  = module.network.network_id
  subnet_id                   = module.network.gke_subnet_id
  pods_range_name             = module.network.pods_range_name
  services_range_name         = module.network.services_range_name
  nodes_service_account_email = module.iam.nodes_service_account_email
  workload_identities         = module.iam.service_account_ids

  # Nodes need their role before they start, or the first Pods fail to start.
  depends_on = [module.iam]
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

module "ingress" {
  source = "../../modules/ingress"

  environment   = var.environment
  region        = var.region
  hostname      = var.hostname
  dns_zone_name = var.dns_zone_name
}

module "deploy_config" {
  source = "../../modules/deploy_config"

  environment   = var.environment
  region        = var.region
  reader_member = local.deployer_member

  values = {
    projectId   = var.project_id
    region      = var.region
    environment = var.environment
    cluster     = module.gke.cluster_name
    imagePrefix = module.registry.image_prefix
    bucket      = module.storage.bucket_name
    ingress = {
      hostname        = module.ingress.hostname
      addressName     = module.ingress.address_name
      certificateName = module.ingress.certificate_name
      proxyOnlyCidr   = var.network.proxy_only_cidr
    }
    database = {
      host           = module.database.endpoint_ip
      name           = module.database.database_name
      user           = module.database.user_name
      passwordSecret = module.secrets.secret_names["db-password"]
      caCert         = module.database.server_ca_cert
    }
    apiTokenSecret = module.secrets.secret_names["api-token"]
    pubsub = {
      endpoint               = "${var.region}-pubsub.googleapis.com:443"
      topic                  = module.queue.documents_topic
      subscription           = module.queue.documents_subscription
      deadLetterSubscription = module.queue.dead_letter_subscription
    }
    serviceAccounts = module.iam.service_account_emails
  }
}
