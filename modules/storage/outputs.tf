output "bucket_name" {
  description = "Name of the data bucket."
  value       = google_storage_bucket.data.name
}
