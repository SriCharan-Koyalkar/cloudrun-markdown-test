
variable "project_id" {
  description = "The project ID where all resources will be launched."
  type        = string
  default     = "gcp-services-369509"
}

/*
variable "network" {
  description = "Name of the network to create resources in."
  default     = "network-1"
}

variable "subnetwork" {
  description = "Name of the subnetwork to create resources in."
  default     = "subnet-1"
}
*/


variable "region" {
  description = "The location (region or zone) to deploy the Cloud Run services. Note: Be sure to pick a region that supports Cloud Run."
  type        = string
  default     = "us-central1"
}
/*
variable "gcr_region" {
  description = "Name of the GCP region where the GCR registry is located. e.g: 'us' or 'eu'."
  type        = string
  default = "us"
}


variable "deploy_db" {
  description = "Whether to deploy a Cloud SQL database or not."
  type        = bool
  default     = false
}

variable "db_instance_name" {
  description = "The name of the Cloud SQL database instance."
  type        = string
  default     = "master-mysql-instance"
}

variable "db_name" {
  description = "The name of the Cloud SQL database."
  type        = string
  default     = "exampledb"
}

variable "db_username" {
  description = "The name of the Cloud SQL database user."
  type        = string
  default     = "testuser"
}

variable "db_password" {
  description = "The password of the Cloud SQL database user."
  type        = string
  default     = "testpassword"
}

variable "db_user_host" {
  description = "The host of the Cloud SQL database user. Used by MySQL."
  type        = string
  default     = "%"
}
*/




