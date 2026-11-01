variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "region" {
  description = "GCP region for all regional resources."
  type        = string
}

variable "environment" {
  description = "Environment name."
  type        = string
}

variable "network" {
  description = "Address ranges of the environment VPC. They must not overlap between environments."
  type = object({
    nodes_cidr      = string
    services_cidr   = string
    pods_cidr       = string
    database_cidr   = string
    proxy_only_cidr = string
  })
}
