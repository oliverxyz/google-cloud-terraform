variable "environment" {
  description = "Environment name, used as a resource name prefix."
  type        = string
}

variable "region" {
  description = "Region of the load balancer address and certificates."
  type        = string
}

variable "hostnames" {
  description = "Public hostname per service, without a trailing dot. All of them share one load balancer."
  type        = map(string)
}

variable "dns_zone_name" {
  description = "Name of the Cloud DNS zone created in bootstrap."
  type        = string
}

variable "dns_ttl_seconds" {
  description = "TTL of the created records. Short, because the address changes on every recreate."
  type        = number
  default     = 60
}
