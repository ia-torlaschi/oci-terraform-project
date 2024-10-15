provider "oci" {
  region = "eu-madrid-1"
}

# VCN
resource "oci_core_vcn" "my_vcn" {
  cidr_block = "10.0.0.0/16"
  display_name = "my_vcn"
  compartment_id = "<compartment_ocid>"
}

# Internet Gateway
resource "oci_core_internet_gateway" "my_igw" {
  compartment_id = oci_core_vcn.my_vcn.compartment_id
  vcn_id = oci_core_vcn.my_vcn.id
  display_name = "my_igw"
  enabled = true
}

# Route Table
resource "oci_core_route_table" "my_rt" {
  compartment_id = oci_core_vcn.my_vcn.compartment_id
  vcn_id         = oci_core_vcn.my_vcn.id
  route_rules {
    network_entity_id = oci_core_internet_gateway.my_igw.id
    cidr_block        = "0.0.0.0/0"
  }
}

# Subnet A (Public Subnet with IGW)
resource "oci_core_subnet" "subnet_a" {
  compartment_id = oci_core_vcn.my_vcn.compartment_id
  vcn_id         = oci_core_vcn.my_vcn.id
  cidr_block     = "10.0.1.0/24"
  display_name   = "public_subnet_a"
  route_table_id = oci_core_route_table.my_rt.id
  security_list_ids = [oci_core_security_list.public_sl.id]
  dns_label = "pubsuba"
}

# Subnet B (Private Subnet, Fault Domain 1)
resource "oci_core_subnet" "subnet_b" {
  compartment_id = oci_core_vcn.my_vcn.compartment_id
  vcn_id         = oci_core_vcn.my_vcn.id
  cidr_block     = "10.0.2.0/24"
  display_name   = "private_subnet_b"
  security_list_ids = [oci_core_security_list.private_sl.id]
  dns_label = "privsubb"
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
}

# Subnet C (Bastion Host, Fault Domain 2)
resource "oci_core_subnet" "subnet_c" {
  compartment_id = oci_core_vcn.my_vcn.compartment_id
  vcn_id         = oci_core_vcn.my_vcn.id
  cidr_block     = "10.0.3.0/24"
  display_name   = "bastion_subnet"
  security_list_ids = [oci_core_security_list.private_sl.id]
  dns_label = "bastionsubc"
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
}

# Subnet D (RAC Database, Fault Domain 3)
resource "oci_core_subnet" "subnet_d" {
  compartment_id = oci_core_vcn.my_vcn.compartment_id
  vcn_id         = oci_core_vcn.my_vcn.id
  cidr_block     = "10.0.4.0/24"
  display_name   = "rac_database_subnet"
  security_list_ids = [oci_core_security_list.private_sl.id]
  dns_label = "racsubd"
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
}

# Security Lists
resource "oci_core_security_list" "public_sl" {
  compartment_id = oci_core_vcn.my_vcn.compartment_id
  vcn_id         = oci_core_vcn.my_vcn.id
  egress_security_rules {
    protocol = "all"
    destination = "0.0.0.0/0"
  }
  ingress_security_rules {
    protocol = "6"
    source = "0.0.0.0/0"
    tcp_options {
      min = 22
      max = 22
    }
  }
}

resource "oci_core_security_list" "private_sl" {
  compartment_id = oci_core_vcn.my_vcn.compartment_id
  vcn_id         = oci_core_vcn.my_vcn.id
  egress_security_rules {
    protocol = "all"
    destination = "0.0.0.0/0"
  }
  ingress_security_rules {
    protocol = "6"
    source = "10.0.0.0/16"
    tcp_options {
      min = 1521
      max = 1521
    }
  }
}

# Bastion Host (VM)
resource "oci_core_instance" "bastion_host" {
  compartment_id = oci_core_vcn.my_vcn.compartment_id
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  shape = "VM.Standard.E3.Flex"
  create_vnic_details {
    subnet_id = oci_core_subnet.subnet_c.id
    assign_public_ip = false
  }
  metadata = {
    ssh_authorized_keys = "<YOUR_SSH_PUBLIC_KEY>"
  }
}

# Database RAC
resource "oci_database_db_system" "rac_db" {
  compartment_id = oci_core_vcn.my_vcn.compartment_id
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  database_edition = "ENTERPRISE_EDITION_EXTREME_PERFORMANCE"
  shape = "VM.Standard2.16"
  node_count = 2
  subnet_id = oci_core_subnet.subnet_d.id
}
