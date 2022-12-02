
provider "google-beta" {
  project = "gcp-services-369509"
  region  = "us-central1"
}


# VPC and Subnets
resource "google_compute_network" "runcloud2" {
  name                    = "runcloud2"
  auto_create_subnetworks = true
  #region = "us-central1"
}

resource "google_compute_subnetwork" "mysubnet2" {
  name          = "mysubnet2"
  ip_cidr_range = "192.168.0.0/28"
  region        = "us-central1"
  network       = google_compute_network.runcloud2.id
}


resource "google_vpc_access_connector" "my-vpc-connector123" {
  name   = "myconnector2"
  region = "us-central1"
  # e.g. "10.8.0.0/28"
  ip_cidr_range = "10.8.0.0/28"
  network       = google_compute_network.runcloud2.id
  #subnet_name = module.km1-runcloud.subnets.subnet_name
}

resource "google_compute_router" "default" {
  provider = google-beta
  name     = "myrouter2"
  network  = google_compute_network.runcloud2.id
  region   = "us-central1"
}


resource "google_compute_address" "default" {
  provider = google-beta
  name     = google_compute_subnetwork.mysubnet2.name
  region   = "us-central1"
}

resource "google_compute_router_nat" "default" {
  provider               = google-beta
  name                   = "mynat2"
  router                 = google_compute_router.default.name
  region                 = "us-central1"
  nat_ip_allocate_option = "AUTO_ONLY"
  #nat_ips                = [google_compute_address.default.self_link]
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
  #subnetwork {
  # name                    = google_compute_subnetwork.default.id
  #source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  #}
}


resource "google_compute_global_address" "private_ip_address" {
  name          = "private-ip-address"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 24
  network       = google_compute_network.runcloud2.id
}


resource "google_service_networking_connection" "default" {
  network                 = google_compute_network.runcloud2.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
}


resource "google_compute_network_peering_routes_config" "peering_routes" {
  peering              = google_service_networking_connection.default.peering
  network              = google_compute_network.runcloud2.name
  import_custom_routes = true
  export_custom_routes = true
}




# cloud sql
resource "google_sql_database_instance" "new-cloud-sql" {
  provider         = google-beta
  name             = "postgres-sql12345"
  database_version = "POSTGRES_11"
  depends_on       = [google_service_networking_connection.default]
  settings {
    tier = "db-f1-micro"
    user_labels = {
      name        = "sql111"
      environment = "demo"
      tier        = "database"
      type        = "postgres"
    }
    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.runcloud2.id
    }
  }
  deletion_protection = false
}

/*
resource "google_compute_network_peering_routes_config" "peering_routes" {
    peering = google_service_networking_connection.default.peering
    network = google_compute_network.runcloud2.name
     import_custom_routes = true
     export_custom_routes = true
     }
*/
#===========================================
#  Cloud RUN
#===========================================

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
        env {
          name  = "INSTANCE_CONNECTION_NAME"
          value = google_sql_database_instance.new-cloud-sql.connection_name
        }
      }
      service_account_name = google_service_account.renderer.email
    }
    metadata {
      annotations = {
        # Use the VPC Connector
        "run.googleapis.com/vpc-access-connector" = google_vpc_access_connector.my-vpc-connector123.name
        "run.googleapis.com/cloudsql-instances"   = google_sql_database_instance.new-cloud-sql.connection_name
        # all egress from the service should go through the VPC Connector
        "run.googleapis.com/vpc-access-egress" = "all-traffic"
      }
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
          value = resource.google_cloud_run_service.renderer.status[0].url
        }
      }
      service_account_name = google_service_account.editor.email
    }
    metadata {
      annotations = {
        # Use the VPC Connector
        "run.googleapis.com/vpc-access-connector" = resource.google_vpc_access_connector.my-vpc-connector123.name
        # all egress from the service should go through the VPC Connector
        "run.googleapis.com/vpc-access-egress" = "all-traffic"
      }
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