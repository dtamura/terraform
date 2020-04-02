resource "google_container_cluster" "primary" {
  name     = "${var.environment}-cluster"
  location = var.zone

  network    = module.vpc01.network_self_link
  subnetwork = module.vpc01.subnets_names[0]
  ip_allocation_policy {
    cluster_secondary_range_name  = "subnet-01-secondary-01"
    services_secondary_range_name = "subnet-01-secondary-02"
  }

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 2
  addons_config {
    http_load_balancing {
      disabled = true
    }

    horizontal_pod_autoscaling {
      disabled = true
    }
    network_policy_config {
      disabled = true
    }
  }

}

resource "google_container_node_pool" "primary_preemptible_nodes" {
  name       = "${var.environment}-node-pool"
  location   = var.zone
  cluster    = google_container_cluster.primary.name
  node_count = 2

  node_config {
    preemptible  = true
    machine_type = "n1-standard-4"
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
