variable "project_id" {
  description = "ID of your GCP project. Make sure you set this up before running this terraform code.  REQUIRED."
  default       = "gcp-services-369509"
}

variable "name" {
  description = "This prefix will be included in the name of some resources. You can use your own name or any other short string here."
  default     = "renderer"
}

variable "location" {
  description = "The region where the resources are created."
  default     = "us-central1"
}

variable "image" {
  description = "The zone where the resources are created."
  default     = "gcr.io/gcp-services-369509/renderer"
}
  