module "trigger" {
  source = "../renderer"
  build = "gcloud builds submit --tag gcr.io/gcp-services-369509/renderer"
}


module "terraform-google-cloud-run" {
  source = "../renderer/"
  name     = var.name
  location = var.location
  image = var.image
  depends_on = [
    module.trigger
  ]
}