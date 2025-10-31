/**
 * GTFS ingest Compute Engine VM
 * Ubuntu 24.04 LTS, e2-micro (2 vCPU / 1 GiB), 200 GB persistent disk.
 * Startup script installs Git and GitHub CLI.
 *
 * Usage:
 *   terraform init
 *   terraform apply \
 *     -var "project_id=YOUR_GCP_PROJECT" \
 *     -var "service_account_email=YOUR_SA@YOUR_GCP_PROJECT.iam.gserviceaccount.com"
 */

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.84"
    }
  }
}

###############################################################################
# Variables
###############################################################################

variable "project_id" {
  description = "GCP project ID where the VM will be created."
  type        = string
}

variable "service_account_email" {
  description = "Service account email to attach to the VM (must already exist)."
  type        = string
}

variable "region" {
  description = "Default region."
  type        = string
  default     = "asia-northeast1"
}

variable "zone" {
  description = "Zone where the VM will live."
  type        = string
  default     = "asia-northeast1-b"
}

# Optional overrides
variable "instance_name" {
  description = "Name of the Compute Engine instance."
  type        = string
  default     = "gtfs-ingest-vm"
}

variable "machine_type" {
  description = "Compute Engine machine type."
  type        = string
  default     = "e2-micro"
}

variable "boot_disk_size_gb" {
  description = "Boot disk size in GB."
  type        = number
  default     = 200
}

###############################################################################
# Provider
###############################################################################

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

###############################################################################
# Compute Engine VM
###############################################################################

resource "google_compute_instance" "gtfs_ingest" {
  name         = var.instance_name
  machine_type = var.machine_type
  tags         = ["gtfs", "ingest"]

  boot_disk {
    initialize_params {
      image = "projects/ubuntu-os-cloud/global/images/family/ubuntu-2404-lts"
      size  = var.boot_disk_size_gb
      type  = "pd-balanced"
    }
  }

  network_interface {
    network       = "default"
    access_config {} # ephemeral public IP
  }

  service_account {
    email  = var.service_account_email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  metadata = {
    enable-oslogin = "TRUE"
  }

  metadata_startup_script = <<-EOT
    #!/bin/bash
    set -euxo pipefail

    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y make

    # Install Git
    DEBIAN_FRONTEND=noninteractive apt-get install -y git

    # Install GitHub CLI
    if ! command -v gh >/dev/null 2>&1; then
      apt-get install -y curl
      mkdir -p /etc/apt/keyrings
      curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | dd of=/etc/apt/keyrings/githubcli-archive-keyring.gpg
      chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        > /etc/apt/sources.list.d/github-cli.list
      apt-get update
      DEBIAN_FRONTEND=noninteractive apt-get install -y gh
    fi

    # Install Docker (official repository)
    DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates curl gnupg
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo \"$VERSION_CODENAME\") stable" \
      > /etc/apt/sources.list.d/docker.list
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    systemctl enable --now docker

    # Install Podman (alternative runtime)
    DEBIAN_FRONTEND=noninteractive apt-get install -y podman podman-compose

    git --version
    gh --version
    docker --version
    podman --version || true
  EOT

  allow_stopping_for_update = true
}

###############################################################################
# Outputs
###############################################################################

output "instance_name" {
  description = "Name of the created Compute Engine instance."
  value       = google_compute_instance.gtfs_ingest.name
}

output "instance_ip" {
  description = "Public IP address of the instance."
  value       = google_compute_instance.gtfs_ingest.network_interface[0].access_config[0].nat_ip
}
