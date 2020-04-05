
variable "region" {
  type    = string
  default = "asia-northeast1"
}
variable "zone" {
  type    = string
  default = "asia-northeast1-c"
}
variable "credentials_path" {
  type = string
}
variable "project_id" {
  type = string
}
variable "environment" {
  type = string
}
variable "subnets_cidrs" { default = [] }
variable "subnet01_secondary_ranges" { default = [] }
variable "client_ip_ranges" { default = [] }



provider "google" {
  version     = "3.5.0"
  credentials = file(var.credentials_path)
  project     = var.project_id
  region      = "asia-northeast1"
  zone        = "asia-northeast1-c"
}

module "vpc01" {
  source  = "terraform-google-modules/network/google"
  version = "~> 2.1"

  project_id   = var.project_id
  network_name = "${var.environment}01"

  subnets = [
    {
      subnet_name               = "subnet-01"
      subnet_ip                 = var.subnets_cidrs[0]
      subnet_region             = "asia-northeast1"
      subnet_private_access     = "true"
      subnet_flow_logs          = "true"
      subnet_flow_logs_interval = "INTERVAL_10_MIN"
      subnet_flow_logs_sampling = 0.5
      subnet_flow_logs_metadata = "INCLUDE_ALL_METADATA"
    },
    {
      subnet_name               = "subnet-02"
      description               = "This subnet has a description"
      subnet_ip                 = var.subnets_cidrs[1]
      subnet_region             = "asia-northeast2"
      subnet_flow_logs          = "true"
      subnet_flow_logs_interval = "INTERVAL_10_MIN"
      subnet_flow_logs_sampling = 0.7
      subnet_flow_logs_metadata = "INCLUDE_ALL_METADATA"
    }
  ]

  secondary_ranges = {
    subnet-01 = [
      {
        range_name    = "subnet-01-secondary-01"
        ip_cidr_range = var.subnet01_secondary_ranges[0]
      },
      {
        range_name    = "subnet-01-secondary-02"
        ip_cidr_range = var.subnet01_secondary_ranges[1]
      },
    ]

    subnet-02 = []
  }

}

resource "google_compute_firewall" "vpc01_allow_internal" {
  name          = "${module.vpc01.network_name}-allow-internal-any"
  network       = module.vpc01.network_name
  source_ranges = concat(var.subnets_cidrs, var.subnet01_secondary_ranges)
  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }
  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }
  allow {
    protocol = "icmp"
  }

}
resource "google_compute_firewall" "vpc01_allow_from_client" {
  name          = "${module.vpc01.network_name}-allow-from-client"
  network       = module.vpc01.network_name
  source_ranges = concat(var.client_ip_ranges)
  allow {
    protocol = "tcp"
    ports    = ["22", "443"]
  }
  allow {
    protocol = "icmp"
  }

}


resource "google_compute_router" "nat_router" {
  name    = "my-nat-router"
  region  = var.region
  network = module.vpc01.network_name
}

resource "google_compute_router_nat" "nat" {
  name                               = "my-nat-config"
  router                             = google_compute_router.nat_router.name
  region                             = google_compute_router.nat_router.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}
