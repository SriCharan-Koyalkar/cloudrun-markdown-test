
variable "project_id" {
  description = "The project ID where all resources will be launched."
  type        = string
  default     = "mindful-faculty-369309"
}
  variable "region" {
  description = "The location (region or zone) to deploy the Cloud Run services. Note: Be sure to pick a region that supports Cloud Run."
  type        = string
  default     = "us-central1"
}

/*
variable "domain" {
  type    = string
  default = "example.com"
}

# -----------------------------------------------------------------------------------
# VPC and Subnets
# -----------------------------------------------------------------------------------

variable "network" {
  description = "Name of the network to create resources in."
  default     = "runcloud22"
}

variable "subnetwork" {
  description = "Name of the subnetwork to create resources in."
  default     = "mysubnet2"
}

variable "ip_cidr_range" {
  description = "The range of internal addresses that are owned by the subnetwork and which is going to be used by VPC Connector. For example, 10.0.0.0/28 or 192.168.0.0/28. Ranges must be unique and non-overlapping within a network. Only IPv4 is supported."
  type        = string
  default = "10.0.0.0/16"
}

variable "proxy_subnet" {
  description = "Name of proxy subnetwork and which is going to be used by VPC Connector."
  type        = string
  default = "my-proxy"
}

variable "vpc_connector_name" {
  description = "The name of the serverless connector which is going to be created."
  type        = string
  default = "myconnector22"
}

# -----------------------------------------------------------------------------------
# cloud sql
# -----------------------------------------------------------------------------------

variable "db_instance_name" {
  description = "The name of the Cloud SQL database instance."
  type        = string
  default     = "postgres-sql32145644"
}

variable "database_version" {
  description = "The version of the database. For example, `MYSQL_5_6` or `POSTGRES_9_6`."
  default     = "POSTGRES_11"
}

variable "tier" {
  description = "The machine tier (First Generation) or type (Second Generation). See this page for supported tiers and pricing: https://cloud.google.com/sql/pricing"
  default     = "db-f1-micro"
}

variable "user_labels" {
  description = "The name of the default user"
  default     = "sql111"
}

#====================================================
# Load Balance
#====================================================

variable "backend-service" {
    description = "backend description"
    type        = string
    default     = "region-service"
}

variable "health_check" {
  description = "perform health checks on."
  type        = string
  default = "health-check"
}

variable "health_check_port" {
  description = "Port to perform health checks on."
  type        = number
  default = 80
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




