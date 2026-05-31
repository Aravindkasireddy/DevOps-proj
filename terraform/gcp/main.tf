terraform {
  required_version = ">= 1.7.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
  backend "gcs" {
    bucket = "fin-enterprise-terraform-state-gcp"
    prefix = "gcp"
  }
}

provider "google" {
  project = var.project
  region  = var.region
}

locals {
  name_prefix = "fin-enterprise-${var.environment}"
}

resource "google_compute_network" "vpc" {
  name                    = "${local.name_prefix}-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "private" {
  name                     = "${local.name_prefix}-private"
  ip_cidr_range            = "10.20.0.0/20"
  region                   = var.region
  network                  = google_compute_network.vpc.id
  private_ip_google_access = true
}

resource "google_container_cluster" "gke" {
  name     = "${local.name_prefix}-gke"
  location = var.region

  remove_default_node_pool = true
  initial_node_count       = 1

  network    = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.private.name

  workload_identity_config {
    workload_pool = "${var.project}.svc.id.goog"
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

  release_channel {
    channel = "REGULAR"
  }

  logging_service    = "logging.googleapis.com/kubernetes"
  monitoring_service = "monitoring.googleapis.com/kubernetes"
}

resource "google_container_node_pool" "primary" {
  name       = "${local.name_prefix}-nodes"
  location   = var.region
  cluster    = google_container_cluster.gke.name
  node_count = var.gke_min_nodes

  autoscaling {
    min_node_count = var.gke_min_nodes
    max_node_count = var.gke_max_nodes
  }

  node_config {
    machine_type = "e2-standard-4"
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
    labels = {
      environment = var.environment
      project     = "fin-enterprise"
    }
  }
}

resource "google_sql_database_instance" "postgres" {
  name             = "${local.name_prefix}-assets-db"
  database_version = "POSTGRES_16"
  region           = var.region

  settings {
    tier              = "db-custom-2-7680"
    availability_type = var.environment == "prod" ? "REGIONAL" : "ZONAL"
    disk_autoresize   = true
    disk_size         = 50

    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.vpc.id
    }

    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = var.environment == "prod"
    }
  }

  deletion_protection = var.environment == "prod"
}

resource "google_sql_database" "assets" {
  name     = "fin_enterprise_assets"
  instance = google_sql_database_instance.postgres.name
}

output "gke_cluster_name" {
  value = google_container_cluster.gke.name
}

output "cloudsql_connection_name" {
  value = google_sql_database_instance.postgres.connection_name
}
