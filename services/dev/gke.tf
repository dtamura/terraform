variable "master_ipv4_cidr_block" {}

resource "google_container_cluster" "primary" {
  name     = "${var.environment}-cluster"
  location = var.zone

  network    = module.vpc01.network_self_link
  subnetwork = module.vpc01.subnets_names[0]
  ip_allocation_policy {
    cluster_secondary_range_name  = "subnet-01-secondary-01"
    services_secondary_range_name = "subnet-01-secondary-02"
  }

  monitoring_service = "monitoring.googleapis.com/kubernetes"

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 2
  addons_config {
    http_load_balancing {
      disabled = false
    }

    horizontal_pod_autoscaling {
      disabled = true
    }
    network_policy_config {
      disabled = true
    }
  }
  private_cluster_config {
    enable_private_nodes    = true

    # When true, the cluster's private endpoint is used as the cluster endpoint 
    #  and access through the public endpoint is disabled. 
    # When false, either endpoint can be used.
    enable_private_endpoint = false 

    master_ipv4_cidr_block  = var.master_ipv4_cidr_block
  }
  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = var.subnets_cidrs[0]
      display_name = "from GCE subnets 1"
    }
    cidr_blocks {
      cidr_block   = var.subnets_cidrs[0]
      display_name = "from GCE subnets 2"
    }
    cidr_blocks {
      cidr_block   = var.client_ip_ranges[0]
      display_name = "from home"
    }
  }

}

resource "google_container_node_pool" "primary_preemptible_nodes" {
  name       = "${var.environment}-node-pool"
  location   = var.zone
  cluster    = google_container_cluster.primary.name
  node_count = 4

  node_config {
    preemptible  = true
    machine_type = "n1-highmem-2"
    disk_size_gb = 40

    service_account = "terraform@dtamura.iam.gserviceaccount.com"

    metadata = {
      disable-legacy-endpoints = "true"
    }

    oauth_scopes = [
      "storage-ro",
      "monitoring",
      "logging-write",
    ]
  }
}
