provider "oci" {
  # tenancy_ocid     = var.tenancy_ocid
  # user_ocid        = var.user_ocid
  # fingerprint      = var.fingerprint
  # private_key_path = var.private_key_path
  region           = "us-phoenix-1"
  config_file_profile = "DEFAULT" 
}

provider "oci" {
  alias            = "home_region"
  # tenancy_ocid     = var.tenancy_ocid
  # user_ocid        = var.user_ocid
  # fingerprint      = var.fingerprint
  # private_key_path = var.private_key_path
  region           = "us-phoenix-1"
  config_file_profile = "DEFAULT" 
}

# Create a new compartment
resource "oci_identity_compartment" "bootcamp_compartment-1" {
  name           = "bootcamp-compartment-1"
  description    = "Compartment for Bootcamp resources"
  compartment_id = var.compartment_id
}

resource "oci_core_vcn" "test_vcn" {
  cidr_block     = "10.0.0.0/16"
  compartment_id = oci_identity_compartment.bootcamp_compartment-1.id
  display_name   = "test-vcn"
  dns_label      = "testvcn"
}

resource "oci_core_subnet" "test_subnet" {
  cidr_block        = "10.0.1.0/24"
  compartment_id    = oci_identity_compartment.bootcamp_compartment-1.id
  vcn_id            = oci_core_vcn.test_vcn.id
  display_name      = "test-subnet"
  dns_label         = "testsubnet"
  route_table_id    = oci_core_route_table.route_table.id
  security_list_ids = [oci_core_vcn.test_vcn.default_security_list_id, oci_core_security_list.oke_api_endpoint_security_list.id]

}

resource "oci_core_subnet" "private_subnet" {
  cidr_block                 = "10.0.2.0/24"
  compartment_id             = oci_identity_compartment.bootcamp_compartment-1.id
  vcn_id                     = oci_core_vcn.test_vcn.id
  display_name               = "private-subnet"
  dns_label                  = "privatesubnet"
  prohibit_public_ip_on_vnic = true
  route_table_id             = oci_core_route_table.private_route_table.id
  security_list_ids = [ oci_core_security_list.private_subnet_security_list.id, oci_core_vcn.test_vcn.default_security_list_id ]
}

# Internet Gateway
resource "oci_core_internet_gateway" "internet_gateway" {
  compartment_id = oci_identity_compartment.bootcamp_compartment-1.id
  vcn_id         = oci_core_vcn.test_vcn.id
  display_name   = "internet-gateway"
}

# NAT Gateway
resource "oci_core_nat_gateway" "nat_gateway" {
  compartment_id = oci_identity_compartment.bootcamp_compartment-1.id
  vcn_id         = oci_core_vcn.test_vcn.id
  display_name   = "nat-gateway"
}

# Route Table
resource "oci_core_route_table" "route_table" {
  compartment_id = oci_identity_compartment.bootcamp_compartment-1.id
  vcn_id         = oci_core_vcn.test_vcn.id
  display_name   = "route-tabeone"

  route_rules {
    destination       = "0.0.0.0/0"
    network_entity_id = oci_core_internet_gateway.internet_gateway.id
  }
}

resource "oci_core_route_table" "private_route_table" {
  compartment_id = oci_identity_compartment.bootcamp_compartment-1.id
  vcn_id         = oci_core_vcn.test_vcn.id
  display_name   = "private-route-table"

  route_rules {
    destination       = "0.0.0.0/0"
    network_entity_id = oci_core_nat_gateway.nat_gateway.id
  }
}

# Add the OKE quickstart module
# Source from https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/containerengine_cluster

resource "oci_containerengine_cluster" "oke-cluster" {
  # Required
  compartment_id     = oci_identity_compartment.bootcamp_compartment-1.id
  kubernetes_version = "v1.31.1"
  name               = "bootcamp-oke-cluster"
  vcn_id             = oci_core_vcn.test_vcn.id
  endpoint_config {
      is_public_ip_enabled = true
      subnet_id = oci_core_subnet.test_subnet.id
  }

  # Optional
  options {
    add_ons {
      is_kubernetes_dashboard_enabled = false
      is_tiller_enabled               = false
    }
    kubernetes_network_config {
      pods_cidr     = "10.244.0.0/16"
      services_cidr = "10.96.0.0/16"
    }
    service_lb_subnet_ids = [oci_core_subnet.test_subnet.id]

  }

}

# Source from https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/containerengine_node_pool

resource "oci_containerengine_node_pool" "oke-node-pool" {
  # Required
  cluster_id         = oci_containerengine_cluster.oke-cluster.id
  compartment_id     = oci_identity_compartment.bootcamp_compartment-1.id
  kubernetes_version = "v1.31.1"
  name               = "pool1"
  node_shape         = "VM.Standard.E3.Flex"

  node_config_details {
    size = 3

    placement_configs {
      availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
      subnet_id           = oci_core_subnet.private_subnet.id
    }
    placement_configs {
      availability_domain = data.oci_identity_availability_domains.ads.availability_domains[1].name
      subnet_id           = oci_core_subnet.private_subnet.id
    }
    placement_configs {
      availability_domain = data.oci_identity_availability_domains.ads.availability_domains[2].name
      subnet_id           = oci_core_subnet.private_subnet.id
    }
  }

  node_shape_config {
    ocpus         = 2  # Specify the desired number of OCPUs
    memory_in_gbs = 16 # Specify the desired memory in GB
  }

  node_source_details {
    image_id    = "ocid1.image.oc1.phx.aaaaaaaatkz7laillswel25edlbmq67ino2y2pv6xhp2lml2vzha44ao5gtq"
    source_type = "image"
  }

  # Optional
  initial_node_labels {
    key   = "name"
    value = "test-oke-node"
  }
}

# Required variables
variable "tenancy_ocid" {}
# variable "user_ocid" {}
# variable "fingerprint" {}
# variable "private_key_path" {}

variable "compartment_id" {}

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}


resource "oci_core_security_list" "oke_api_endpoint_security_list" {
  compartment_id = oci_identity_compartment.bootcamp_compartment-1.id
  vcn_id         = oci_core_vcn.test_vcn.id
  display_name   = "oke-api-endpoint-security-list"

  ingress_security_rules {
    source      = "0.0.0.0/0"
    protocol    = "all"
    description = "Allow access to Kubernetes API "
    stateless   = false


  }

  ingress_security_rules {
    source      = "10.0.0.0/16"
    protocol    = "all"
    description = "Allow access to Kubernetes API endpoint from OCI services"
    stateless   = false

  }
  egress_security_rules {
        protocol = "All"
        destination = "0.0.0.0/0"
    }

}
resource "oci_core_security_list" "private_subnet_security_list" {
  compartment_id = oci_identity_compartment.bootcamp_compartment-1.id
  vcn_id         = oci_core_vcn.test_vcn.id
  display_name   = "private-subnet-security-list"

  egress_security_rules {
    protocol         = "6" # TCP
    destination      = "0.0.0.0/0"
    destination_type = "CIDR_BLOCK"
    stateless       = false
    description     = "Allow HTTPS access to internet"
    
    tcp_options {
      min = 443
      max = 443
    }
  }

  ingress_security_rules {
    protocol = "all"
    source   = "10.0.0.0/16"
    stateless = false
  }
}