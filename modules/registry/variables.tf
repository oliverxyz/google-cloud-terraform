variable "project_id" {
  description = "GCP project ID, used to build the image URL prefix."
  type        = string
}

variable "environment" {
  description = "Environment name, used as a resource name prefix."
  type        = string
}

variable "region" {
  description = "Repository location."
  type        = string
}

variable "reader_member" {
  description = "IAM member allowed to pull images, normally the GKE nodes service account."
  type        = string
}

variable "writer_member" {
  description = "IAM member allowed to push images, normally the GitHub Actions deployer."
  type        = string
}
