# Example Terraform configuration for GCP deployment
# This would go in infrastructure/terraform/main.tf

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Cloud Run for Frontend
resource "google_cloud_run_service" "frontend" {
  name     = "noisenet-frontend"
  location = var.region

  template {
    spec {
      containers {
        image = "gcr.io/${var.project_id}/noisenet-frontend:latest"
        ports {
          container_port = 3000
        }
      }
    }
  }
}

# Cloud Run for Backend API
resource "google_cloud_run_service" "backend" {
  name     = "noisenet-backend"
  location = var.region

  template {
    spec {
      containers {
        image = "gcr.io/${var.project_id}/noisenet-backend:latest"
        ports {
          container_port = 8000
        }
        env {
          name  = "DATABASE_URL"
          value = "postgresql://${google_sql_user.noisenet_user.name}:${random_password.db_password.result}@${google_sql_database_instance.noisenet_db.connection_name}/noisenet"
        }
      }
    }
  }
}

# Cloud SQL PostgreSQL instance
resource "google_sql_database_instance" "noisenet_db" {
  name             = "noisenet-db"
  database_version = "POSTGRES_14"
  region           = var.region

  settings {
    tier = "db-f1-micro"  # Start small, scale up
    
    backup_configuration {
      enabled = true
      start_time = "03:00"
    }
    
    ip_configuration {
      ipv4_enabled = false
      private_network = google_compute_network.noisenet_vpc.self_link
    }
  }
}

resource "google_sql_database" "noisenet" {
  name     = "noisenet"
  instance = google_sql_database_instance.noisenet_db.name
}

# VPC Network
resource "google_compute_network" "noisenet_vpc" {
  name                    = "noisenet-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "noisenet_subnet" {
  name          = "noisenet-subnet"
  ip_cidr_range = "10.0.0.0/24"
  region        = var.region
  network       = google_compute_network.noisenet_vpc.id
}

# Variables
variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "europe-west3"  # Frankfurt for GDPR compliance
}

# Random password for database
resource "random_password" "db_password" {
  length  = 16
  special = true
}

resource "google_sql_user" "noisenet_user" {
  name     = "noisenet"
  instance = google_sql_database_instance.noisenet_db.name
  password = random_password.db_password.result
}