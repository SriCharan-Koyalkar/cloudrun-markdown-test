

/* Copyright 2022 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */


/*
# [START vpc_serverless_connector_enable_api]
resource "google_project_service" "vpcaccess_api" {
  service            = "vpcaccess.googleapis.com"
  provider           = google-beta
  disable_on_destroy = false
}
# [END vpc_serverless_connector_enable_api]

# [START vpc_serverless_connector]
# VPC
resource "google_compute_network" "default" {
  name                    = "cloudrun-network"
  provider                = google-beta
  auto_create_subnetworks = false
}

# VPC access connector
resource "google_vpc_access_connector" "connector" {
  name           = "vpcconn"
  provider       = google-beta
  region         = "us-west1"
  ip_cidr_range  = "10.8.0.0/28"
  max_throughput = 300
  network        = google_compute_network.default.name
  depends_on     = [google_project_service.vpcaccess_api]
}

# Cloud Router
resource "google_compute_router" "router" {
  name     = "router"
  provider = google-beta
  region   = "us-west1"
  network  = google_compute_network.default.id
}

# NAT configuration
resource "google_compute_router_nat" "router_nat" {
  name                               = "nat"
  provider                           = google-beta
  region                             = "us-west1"
  router                             = google_compute_router.router.name
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
  nat_ip_allocate_option             = "AUTO_ONLY"
}
# [END vpc_serverless_connector]

# [START cloudrun_vpc_serverless_connector]
# Cloud Run service
resource "google_cloud_run_service" "gcr_service" {
  name     = "mygcrservice"
  provider = google-beta
  location = "us-west1"

  template {
    spec {
      containers {
        image = "gcr.io/gcp-services-369509/renderer"
        resources {
          limits = {
            cpu    = "1000m"
            memory = "512M"
          }
        }
      }
      # the service uses this SA to call other Google Cloud APIs
      # service_account_name = myservice_runtime_sa
    }

    metadata {
      annotations = {
        # Limit scale up to prevent any cost blow outs!
        "autoscaling.knative.dev/maxScale" = "5"
        # Use the VPC Connector
        "run.googleapis.com/vpc-access-connector" = google_vpc_access_connector.connector.name
        # all egress from the service should go through the VPC Connector
        "run.googleapis.com/vpc-access-egress" = "all-traffic"
      }
    }
  }
  autogenerate_revision_name = true
}
# [END cloudrun_vpc_serverless_connector]

#=========================================
#   SQL Connection
#=========================================

# Project data
data "google_project" "project" {
  project_id = "gcp-services-369509"
}

# Enable Secret Manager API
resource "google_project_service" "secretmanager_api" {
  service            = "secretmanager.googleapis.com"
  disable_on_destroy = false
}

# Enable SQL Admin API
resource "google_project_service" "sqladmin_api" {
  service            = "sqladmin.googleapis.com"
  disable_on_destroy = false
}

# Enable Cloud Run API
resource "google_project_service" "cloudrun_api" {
  service            = "run.googleapis.com"
  disable_on_destroy = false
}


# Creates SQL instance (~15 minutes to fully spin up)
resource "google_sql_database_instance" "mysql_instance" {
  name             = "sqlinstance-555"
  region           = "us-central1"
  database_version = "MYSQL_8_0"
  root_password    = "abcABC123!"

  settings {
    tier = "db-f1-micro"
    password_validation_policy {
      min_length                  = 6
      complexity                  = "COMPLEXITY_DEFAULT"
      reuse_interval              = 2
      disallow_username_substring = true
      enable_password_policy      = true
    }
  }
  deletion_protection = false # set to true to prevent destruction of the resource
  depends_on          = [google_project_service.sqladmin_api]
}


# [START cloudrun_service_cloudsql_dbuser_secret]

# Create dbuser secret
resource "google_secret_manager_secret" "dbuser1" {
  secret_id = "dbusersecret1"
  replication {
    automatic = true
  }
  depends_on = [google_project_service.secretmanager_api]
}

# Attaches secret data for dbuser secret
resource "google_secret_manager_secret_version" "dbuser_data1" {
  secret      = google_secret_manager_secret.dbuser1.id
  secret_data = "secret-data1" # Stores secret as a plain txt in state
}


  
# Update service account for dbuser secret
resource "google_secret_manager_secret_iam_member" "secretaccess_compute_dbuser1" {
  secret_id = google_secret_manager_secret.dbuser1.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${data.google_project.project.number}-compute@developer.gserviceaccount.com" # Project's compute service account
}

# [END cloudrun_service_cloudsql_dbuser_secret]


# [START cloudrun_service_cloudsql_dbpass_secret]

# Create dbpass secret
resource "google_secret_manager_secret" "dbpass1" {
  secret_id = "dbpasssecret1"
  replication {
    automatic = true
  }
  depends_on = [google_project_service.secretmanager_api]
}

# Attaches secret data for dbpass secret
resource "google_secret_manager_secret_version" "dbpass_data1" {
  secret      = google_secret_manager_secret.dbpass1.id
  secret_data = "secret-data1" # Stores secret as a plain txt in state
}

# Update service account for dbpass secret
resource "google_secret_manager_secret_iam_member" "secretaccess_compute_dbpass1" {
  secret_id = google_secret_manager_secret.dbpass1.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${data.google_project.project.number}-compute@developer.gserviceaccount.com" # Project's compute service account
}

# [END cloudrun_service_cloudsql_dbpass_secret]

# [START cloudrun_service_cloudsql_dbname_secret]

# Create dbname secret
resource "google_secret_manager_secret" "dbname1" {
  secret_id = "dbnamesecret1"
  replication {
    automatic = true
  }
  depends_on = [google_project_service.secretmanager_api]
}

# Attaches secret data for dbname secret
resource "google_secret_manager_secret_version" "dbname_data1" {
  secret      = google_secret_manager_secret.dbname1.id
  secret_data = "secret-data1" # Stores secret as a plain txt in state
}

# Update service account for dbname secret
resource "google_secret_manager_secret_iam_member" "secretaccess_compute_dbname1" {
  secret_id = google_secret_manager_secret.dbname1.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${data.google_project.project.number}-compute@developer.gserviceaccount.com" # Project's compute service account
}

# [END cloudrun_service_cloudsql_dbname_secret]


#=========================================
#   Cloud Run
#=========================================

resource "null_resource" "git_clone" {
  provisioner "local-exec" {
    command = "cd ../renderer/"
  }

  #   provisioner "local-exec" {
  #     command = "cd nodejs-docs-samples/run/markdown-preview/renderer/" 
  #   }
  provisioner "local-exec" {
    command = "gcloud builds submit --tag gcr.io/gcp-services-369509/renderer"
  }
}
/*
# [START cloudrun_secure_services_backend]
resource "google_cloud_run_service" "renderer" {
  provider = google-beta
  name     = "renderer"
  location = "us-central1"
  template {
    spec {
      containers {
        # Replace with the URL of your Secure Services > Renderer image.
        #   gcr.io/<PROJECT_ID>/renderer
        image = "gcr.io/gcp-services-369509/renderer"
      }
      service_account_name = google_service_account.renderer.email
    }
  }
  traffic {
    percent         = 100
    latest_revision = true
  }

  depends_on = [
    null_resource.git_clone
  ]

}
# [END cloudrun_secure_services_backend]

*/

/*
# [START cloudrun_secure_services_backend]

resource "google_cloud_run_service" "renderer" {

  provider = google-beta

  name = "renderer"

  location = "us-central1"
  template {

    spec {

      containers {

        # Replace with the URL of your Secure Services > Renderer image.

        #   gcr.io/<PROJECT_ID>/renderer

        image = "gcr.io/gcp-services-369509/renderer"

        # Sets a environment variable for instance connection name
        env {
          name  = "INSTANCE_CONNECTION_NAME"
          value = google_sql_database_instance.mysql_instance.connection_name
        }
        # Sets a secret environment variable for database user secret
        env {
          name = "DB_USER_ONE"
          value_from {
            secret_key_ref {
              name = google_secret_manager_secret.dbuser1.secret_id # secret name
              key  = "latest"                                       # secret version number or 'latest'
            }
          }
        }
        # Sets a secret environment variable for database password secret
        env {
          name = "DB_PASS_ONE"
          value_from {
            secret_key_ref {
              name = google_secret_manager_secret.dbpass1.secret_id # secret name
              key  = "latest"                                       # secret version number or 'latest'
            }
          }
        }
        # Sets a secret environment variable for database name secret
        env {
          name = "DB_NAME_ONE"
          value_from {
            secret_key_ref {
              name = google_secret_manager_secret.dbname1.secret_id # secret name
              key  = "latest"                                       # secret version number or 'latest'
            }
          }
        }
      }
      service_account_name = google_service_account.renderer.email
    }

    metadata {
      annotations = {
        "run.googleapis.com/client-name" = "terraform"
      }
    }
  }

  autogenerate_revision_name = true
  depends_on                 = [null_resource.git_clone, google_project_service.secretmanager_api, google_project_service.cloudrun_api, google_project_service.sqladmin_api]

  traffic {
    percent         = 100
    latest_revision = true
  }
}
# [END cloudrun_secure_services_backend]

*/

/*
resource "null_resource" "editor" {
  provisioner "local-exec" {
    command = "gcloud builds submit --tag gcr.io/gcp-services-369509/editor"
  }
}

# [START cloudrun_secure_services_frontend]
resource "google_cloud_run_service" "editor" {
  provider = google-beta
  name     = "editor"
  location = "us-central1"
  template {
    spec {
      containers {
        # Replace with the URL of your Secure Services > Editor image.
        #   gcr.io/<PROJECT_ID>/editor
        image = "gcr.io/gcp-services-369509/editor"
        env {
          name  = "EDITOR_UPSTREAM_RENDER_URL"
          value = google_cloud_run_service.renderer.status[0].url
        }
      }
      service_account_name = google_service_account.editor.email
    }
  }
  traffic {
    percent         = 100
    latest_revision = true
  }
  depends_on = [
    null_resource.editor
  ]
}
# [END cloudrun_secure_services_frontend]

*/

/*

# [START cloudrun_secure_services_frontend]
resource "null_resource" "editor" {
  provisioner "local-exec" {
    command = "gcloud builds submit --tag gcr.io/gcp-services-369509/editor"
  }
}

resource "google_cloud_run_service" "editor" {

  provider = google-beta

  name = "editor"

  location = "us-central1"

  template {

    spec {

      containers {

        # Replace with the URL of your Secure Services > Editor image.

        #   gcr.io/<PROJECT_ID>/editor

        image = "gcr.io/gcp-services-369509/editor"
        env {
          name  = "EDITOR_UPSTREAM_RENDER_URL"
          value = google_cloud_run_service.renderer.status[0].url
        }
        env {
          name  = "INSTANCE_CONNECTION_NAME"
          value = google_sql_database_instance.mysql_instance.connection_name
        }
        # Sets a secret environment variable for database user secret
        env {
          name = "DB_USER_ONE"
          value_from {
            secret_key_ref {
              name = google_secret_manager_secret.dbuser1.secret_id # secret name
              key  = "latest"                                       # secret version number or 'latest'
            }
          }
        }
        # Sets a secret environment variable for database password secret
        env {
          name = "DB_PASS_ONE"
          value_from {
            secret_key_ref {
              name = google_secret_manager_secret.dbpass1.secret_id # secret name
              key  = "latest"                                       # secret version number or 'latest'
            }
          }
        }
        # Sets a secret environment variable for database name secret
        env {
          name = "DB_NAME_ONE"
          value_from {
            secret_key_ref {
              name = google_secret_manager_secret.dbname1.secret_id # secret name
              key  = "latest"                                       # secret version number or 'latest'
            }
          }
        }
      }
      service_account_name = google_service_account.editor.email
    }
    metadata {
      annotations = {
        "autoscaling.knative.dev/maxScale"      = "1" # no clusting
        "run.googleapis.com/cloudsql-instances" = google_sql_database_instance.mysql_instance.connection_name
      }
    }
  }
  traffic {
    percent         = 100
    latest_revision = true
  }
  autogenerate_revision_name = true
  depends_on = [
    null_resource.editor, google_project_service.secretmanager_api, google_project_service.cloudrun_api, google_project_service.sqladmin_api
  ]
}

# [END cloudrun_secure_services_frontend]
*/

/*
# [START cloudrun_secure_services_backend_identity]
resource "google_service_account" "renderer" {
  provider     = google-beta
  account_id   = "renderer-identity"
  display_name = "Service identity of the Renderer (Backend) service."
}
# [END cloudrun_secure_services_backend_identity]

# [START cloudrun_secure_services_frontend_identity]
resource "google_service_account" "editor" {
  provider     = google-beta
  account_id   = "editor-identity"
  display_name = "Service identity of the Editor (Frontend) service."
}
# [END cloudrun_secure_services_frontend_identity]

# [START cloudrun_secure_services_backend_invoker_access]
resource "google_cloud_run_service_iam_member" "editor_invokes_renderer" {
  provider = google-beta
  location = google_cloud_run_service.renderer.location
  service  = google_cloud_run_service.renderer.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.editor.email}"
}
# [END cloudrun_secure_services_backend_invoker_access]

# [START cloudrun_secure_services_frontend_access]
data "google_iam_policy" "noauth" {
  provider = google-beta
  binding {
    role = "roles/run.invoker"
    members = [
      "allUsers",
    ]
  }
}

resource "google_cloud_run_service_iam_policy" "noauth" {
  provider = google-beta
  location = google_cloud_run_service.editor.location
  project  = google_cloud_run_service.editor.project
  service  = google_cloud_run_service.editor.name

  policy_data = data.google_iam_policy.noauth.policy_data
}
# [END cloudrun_secure_services_frontend_access
*/