variable "environment" {
  description = "Environment name, used as a resource name prefix."
  type        = string
}

variable "region" {
  description = "Region of the subnets."
  type        = string
}

variable "nodes_cidr" {
  description = "Primary range of the GKE subnet, used by nodes."
  type        = string
}

variable "services_cidr" {
  description = "Secondary range of the GKE subnet, used by Kubernetes Services."
  type        = string
}

variable "pods_cidr" {
  description = "Secondary range of the GKE subnet, used by Pods."
  type        = string
}

variable "database_cidr" {
  description = "Range of the subnet that holds only the Private Service Connect endpoint of the database."
  type        = string
}

variable "proxy_only_cidr" {
  description = "Range reserved for the managed proxies of the regional external Application Load Balancer."
  type        = string
}

variable "database_port" {
  description = "The only TCP port allowed towards the database subnet."
  type        = number
  default     = 5432
}
