/*
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


resource "null_resource" "editor" {
  provisioner "local-exec" {
    command = "cd ../editor/"
  }

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
*/