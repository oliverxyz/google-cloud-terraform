variable "project_id" {
  description = "GCP project ID, makes the global bucket name unique."
  type        = string
}

variable "environment" {
  description = "Environment name, used as a resource name prefix."
  type        = string
}

variable "region" {
  description = "Bucket location."
  type        = string
}

variable "grants" {
  description = "Bucket access grants, keyed by a static name. The key must not depend on apply-time values."
  type = map(object({
    role   = string
    member = string
  }))
  default = {}
}
