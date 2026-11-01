variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "environment" {
  description = "Environment name, used as a resource name prefix."
  type        = string
}

variable "region" {
  description = "The only region where messages may be stored and transit."
  type        = string
}

variable "max_delivery_attempts" {
  description = "Delivery attempts before a message moves to the dead-letter topic. Pub/Sub allows 5 to 100."
  type        = number
  default     = 5

  validation {
    condition     = var.max_delivery_attempts >= 5 && var.max_delivery_attempts <= 100
    error_message = "Pub/Sub allows 5 to 100 delivery attempts."
  }
}

variable "publisher_member" {
  description = "IAM member allowed to publish to the documents topic."
  type        = string
}

variable "subscriber_member" {
  description = "IAM member allowed to consume the documents subscription."
  type        = string
}

variable "dead_letter_subscriber_member" {
  description = "IAM member allowed to consume the dead-letter subscription."
  type        = string
}
