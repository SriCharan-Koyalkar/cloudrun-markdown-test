
provider "google-beta" {
  project = var.project_id
  region  = var.region
}


# -----------------------------------------------------------------------------------
# VPC and Subnets
# -----------------------------------------------------------------------------------

resource "google_compute_network" "runcloud55" {
  name                    = "runcloud55"
  project                 = var.project_id
  auto_create_subnetworks = false
  #region = "us-central1"
}

resource "google_compute_subnetwork" "mysubnet55" {
  name          = "mysubnet55"
  project       = var.project_id
  ip_cidr_range = "10.0.0.0/16"
  region        = var.region
  network       = google_compute_network.runcloud55.id
}


resource "google_compute_subnetwork" "proxy_subnet" {
  name          = "my-proxy"
  project       = var.project_id
  ip_cidr_range = "10.2.0.0/16"
  region        = "us-central1"
  network       = google_compute_network.runcloud55.id
  purpose       = "REGIONAL_MANAGED_PROXY"
  role          = "ACTIVE"
}


resource "google_vpc_access_connector" "my-vpc-connector55" {
  name    = "myconnector121"
  project = var.project_id
  region  = "us-central1"
  # e.g. "10.8.0.0/28"
  ip_cidr_range = "10.8.0.0/28"
  network       = google_compute_network.runcloud55.id
  #subnet_name = module.km1-runcloud.subnets.subnet_name
}


resource "google_compute_router" "default" {
  provider = google-beta
  name     = "myrouter1234"
  network  = google_compute_network.runcloud55.id
  region   = "us-central1"
}


/*
resource "google_compute_address" "default" {
  provider = google-beta
  name     = "my-compute-add"
  region   = "us-central1"
}
*/

resource "google_compute_address" "default" {
  name         = "my-internal-address"
  project = var.project_id
  subnetwork   = google_compute_subnetwork.mysubnet55.id
  address_type = "INTERNAL"
  address      = "10.0.42.42"
  region       = var.region
}

/*
resource "google_compute_address" "default" {
    name    = "defaultcompute-address"   
    region       = "us-central1"  
    address_type = "INTERNAL"  
    purpose      = "SHARED_LOADBALANCER_VIP"   
    subnetwork   = google_compute_subnetwork.mysubnet55.id
}
*/

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
  project       = var.project_id
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 24
  network       = google_compute_network.runcloud55.id
}


resource "google_service_networking_connection" "default" {
  network                 = google_compute_network.runcloud55.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
}


resource "google_compute_network_peering_routes_config" "peering_routes" {
  peering              = google_service_networking_connection.default.peering
  network              = google_compute_network.runcloud55.name
  import_custom_routes = true
  export_custom_routes = true
}

# -----------------------------------------------------------------------------------
# cloud sql
# -----------------------------------------------------------------------------------

resource "google_sql_database_instance" "new-cloud-sql" {
  provider         = google-beta
  name             = "postgres-sql4444"
  project          = var.project_id
  database_version = "POSTGRES_11"
  depends_on       = [google_service_networking_connection.default]
  settings {
    tier = "db-f1-micro"
    user_labels = {
      name        = "sql123"
      environment = "demo"
      tier        = "database"
      type        = "postgres"
    }
    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.runcloud55.id
    }
  }
  deletion_protection = false
}


/*
resource "google_compute_network_peering_routes_config" "peering_routes" {
    peering = google_service_networking_connection.default.peering
    network = google_compute_network.runcloud55.name
     import_custom_routes = true
     export_custom_routes = true
     }
*/


#====================================================
# Load Balance
#===================================================
# Load Balancing resources

resource "google_compute_region_backend_service" "backend-service" {
  project               = var.project_id
  region                = var.region
  name                  = "region-service"
  protocol              = "HTTP"
  load_balancing_scheme = "INTERNAL_MANAGED"

  backend {
    group           = google_compute_region_network_endpoint_group.cloudrun_neg.id
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }
}

resource "google_compute_health_check" "health-check" {
  name    = "health-check"
  project = var.project_id
  http_health_check {
    port = 80
  }
}

resource "google_compute_region_network_endpoint_group" "cloudrun_neg" {
  name                  = "cloudrun-neg"
  network_endpoint_type = "SERVERLESS"
  region                = var.region
  cloud_run {
    service = google_cloud_run_service.editor.name
  }
}

resource "google_compute_region_url_map" "regionurlmap" {
  project         = var.project_id
  name            = "regionurlmap"
  description     = "Created with Terraform"
  region          = var.region
  default_service = google_compute_region_backend_service.backend-service.id
}

resource "google_compute_region_target_http_proxy" "targethttpproxy" {
  project = var.project_id
  region  = var.region
  name    = "test-proxy"
  url_map = google_compute_region_url_map.regionurlmap.id
}

resource "google_compute_forwarding_rule" "forwarding_rule" {
  name                  = "l7-ilb-forwarding-rule"
  provider              = google-beta
  region                = var.region
  depends_on            = [google_compute_subnetwork.proxy_subnet]
  ip_protocol           = "TCP"
  load_balancing_scheme = "INTERNAL_MANAGED"
  //ip_address            = google_compute_address.default.name
  // ip_address            = join("", google_compute_address.default.*.id)
  port_range = "80"
  target     = google_compute_region_target_http_proxy.targethttpproxy.id
  network    = google_compute_network.runcloud55.id
  subnetwork = google_compute_subnetwork.mysubnet55.id
}


#===========================================
#  Cloud RUN
#===========================================

# resource "null_resource" "git_clone" {
#   provisioner "local-exec" {
#     command = "cd ../renderer/"
#   }

#   #   provisioner "local-exec" {
#   #     command = "cd nodejs-docs-samples/run/markdown-preview/renderer/" 
#   #   }
#   provisioner "local-exec" {
#     command = "gcloud builds submit --tag gcr.io/gcp-services-369509/renderer"
#   }
# }

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
        "run.googleapis.com/vpc-access-connector" = google_vpc_access_connector.my-vpc-connector55.name
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
    google_vpc_access_connector.my-vpc-connector55
  ]
}
# [END cloudrun_secure_services_backend]


# resource "null_resource" "editor" {
#   provisioner "local-exec" {
#     command = "gcloud builds submit --tag gcr.io/gcp-services-369509/editor"
#   }
# }

# [START cloudrun_secure_services_frontend]
resource "google_cloud_run_service" "editor" {
  provider = google-beta
  name     = "editor"
  location = "us-central1"
  metadata {
    annotations = {
      "run.googleapis.com/ingress" = "internal"
    }
  }
  template {
    spec {
      containers {
        # Replace with the URL of your Secure Services > Editor image.
        #   gcr.io/<PROJECT_ID>/editor
        image = "gcr.io/gcp-services-369509/editor"
        ports {
          name           = "h2c"
          container_port = 8080
        }
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
        "run.googleapis.com/vpc-access-connector" = resource.google_vpc_access_connector.my-vpc-connector55.name
        # all egress from the service should go through the VPC Connector
        "run.googleapis.com/vpc-access-egress" = "all-traffic"
        //"run.googleapis.com/ingress" = "internal"
        // "run.googleapis.com/ingress"       = "all"
        //"run.googleapis.com/ingress" = "internal-and-cloud-load-balancing" // variable set to "internal-and-cloud-load-balancing"
      }
    }
  }
  traffic {
    percent         = 100
    latest_revision = true
  }
  depends_on = [
    google_vpc_access_connector.my-vpc-connector55
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



#===================================================
output "backend_url" {
  value = google_cloud_run_service.renderer.status[0].url
}

output "frontend_url" {
  value = google_cloud_run_service.editor.status[0].url
}
