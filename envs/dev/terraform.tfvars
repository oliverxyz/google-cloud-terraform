project_id  = "infrastructure-test-plan"
region      = "europe-southwest1"
environment = "dev"

network = {
  nodes_cidr      = "10.10.0.0/22"
  services_cidr   = "10.10.4.0/22"
  database_cidr   = "10.10.8.0/28"
  proxy_only_cidr = "10.10.12.0/23"
  pods_cidr       = "10.10.128.0/17"
}

database = {
  tier              = "db-f1-micro"
  availability_type = "ZONAL"
  disk_size_gb      = 10
  backups_enabled   = false
}
