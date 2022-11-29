variable "name" {
  description = "This prefix will be included in the name of some resources. You can use your own name or any other short string here."
  default     = "gcp-tf"
}

variable "location" {
  description = "The region where the resources are created."
  default     = "us-central1"
}

variable "image" {
  description = "The zone where the resources are created."
  default     = "gcr.io/gcp-services-369509/renderer"
}
