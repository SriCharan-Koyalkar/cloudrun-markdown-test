/*
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
  name             = "sqlinstance-1223"
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
resource "google_secret_manager_secret" "dbuser" {
  secret_id = "dbusersecret"
  replication {
    automatic = true
  }
  depends_on = [google_project_service.secretmanager_api]
}

# Attaches secret data for dbuser secret
resource "google_secret_manager_secret_version" "dbuser_data" {
  secret      = google_secret_manager_secret.dbuser.id
  secret_data = "secret-data" # Stores secret as a plain txt in state
}

# Update service account for dbuser secret
resource "google_secret_manager_secret_iam_member" "secretaccess_compute_dbuser" {
  secret_id = google_secret_manager_secret.dbuser.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${data.google_project.project.number}-compute@developer.gserviceaccount.com" # Project's compute service account
}

# [END cloudrun_service_cloudsql_dbuser_secret]


# [START cloudrun_service_cloudsql_dbpass_secret]

# Create dbpass secret
resource "google_secret_manager_secret" "dbpass" {
  secret_id = "dbpasssecret"
  replication {
    automatic = true
  }
  depends_on = [google_project_service.secretmanager_api]
}

# Attaches secret data for dbpass secret
resource "google_secret_manager_secret_version" "dbpass_data" {
  secret      = google_secret_manager_secret.dbpass.id
  secret_data = "secret-data" # Stores secret as a plain txt in state
}

# Update service account for dbpass secret
resource "google_secret_manager_secret_iam_member" "secretaccess_compute_dbpass" {
  secret_id = google_secret_manager_secret.dbpass.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${data.google_project.project.number}-compute@developer.gserviceaccount.com" # Project's compute service account
}

# [END cloudrun_service_cloudsql_dbpass_secret]

# [START cloudrun_service_cloudsql_dbname_secret]

# Create dbname secret
resource "google_secret_manager_secret" "dbname" {
  secret_id = "dbnamesecret"
  replication {
    automatic = true
  }
  depends_on = [google_project_service.secretmanager_api]
}

# Attaches secret data for dbname secret
resource "google_secret_manager_secret_version" "dbname_data" {
  secret      = google_secret_manager_secret.dbname.id
  secret_data = "secret-data" # Stores secret as a plain txt in state
}

# Update service account for dbname secret
resource "google_secret_manager_secret_iam_member" "secretaccess_compute_dbname" {
  secret_id = google_secret_manager_secret.dbname.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${data.google_project.project.number}-compute@developer.gserviceaccount.com" # Project's compute service account
}

# [END cloudrun_service_cloudsql_dbname_secret]







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
        image = "gcr.io/gcp-services-369509/renderer"  # Image to deploy

        # Sets a environment variable for instance connection name
        env {
          name  = "INSTANCE_CONNECTION_NAME"
          value = google_sql_database_instance.mysql_instance.connection_name
        }
        # Sets a secret environment variable for database user secret
        env {
          name = "DB_USER"
          value_from {
            secret_key_ref {
              name = google_secret_manager_secret.dbuser.secret_id # secret name
              key  = "latest"                                      # secret version number or 'latest'
            }
          }
        }
        # Sets a secret environment variable for database password secret
        env {
          name = "DB_PASS"
          value_from {
            secret_key_ref {
              name = google_secret_manager_secret.dbpass.secret_id # secret name
              key  = "latest"                                      # secret version number or 'latest'
            }
          }
        }
        # Sets a secret environment variable for database name secret
        env {
          name = "DB_NAME"
          value_from {
            secret_key_ref {
              name = google_secret_manager_secret.dbname.secret_id # secret name
              key  = "latest"                                      # secret version number or 'latest'
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
# [END cloudrun_service_cloudsql_default_service]


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
# [END cloudrun_secure_services_frontend_access]

output "backend_url" {
  value = google_cloud_run_service.renderer.status[0].url
}

output "frontend_url" {
  value = google_cloud_run_service.editor.status[0].url
}
*/