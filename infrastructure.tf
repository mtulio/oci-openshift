## Default region
variable home_region { 
    type = string
    description = "The region identifier of the home region where the tenancy's IAM and compartment resources are defined. For more detail regarding region identifiers, please visit https://docs.oracle.com/en-us/iaas/Content/General/Concepts/regions.htm . "
}
variable zone_dns {
    type        = string
    description = "The name of cluster's DNS zone. This name must be the same as what was specified during OpenShift ISO creation."
}
variable master_count {
    default     = 3
    type        = number
    description = "The number of master nodes in the cluster. The default value is 3. "
}
variable master_shape {
    default     = "VM.Standard.E4.Flex" 
    description = "Compute shape of the master nodes. The default shape is VM.Standard.E4.Flex. For more detail regarding compute shapes, please visit https://docs.oracle.com/en-us/iaas/Content/Compute/References/computeshapes.htm ."
}
variable master_ocpu {
    default     = 4
    type        = number
    description = "The number of OCPUs available for the shape of each master node. The default value is 4. "
}
variable master_memory {
    default     = 16
    type        = number
    description = "The amount of memory available for the shape of each master node, in gigabytes. The default value is 16. "
}
variable master_boot_size {
    default     = 500
    type        = number
    description = "The size of the boot volume of each master node in GBs. The minimum value is 50 GB and the maximum value is 32,768 GB (32 TB). The default value is 500 GB. "
}
variable master_boot_volume_vpus_per_gb {
    default     = 60
    type        = number
    description = "The number of volume performance units (VPUs) that will be applied to this volume per GB of each master node. The default value is 60. "
}
variable worker_count {
    default     = 3
    type        = number
    description = "The number of worker nodes in the cluster. The default value is 3. "
}
variable worker_shape {
    default     = "VM.Standard.E4.Flex" 
    description = "Compute shape of the worker nodes. The default shape is VM.Standard.E4.Flex. For more detail regarding compute shapes, please visit https://docs.oracle.com/en-us/iaas/Content/Compute/References/computeshapes.htm "
}
variable worker_ocpu {
    default     = 4
    type        = number
    description = "The number of OCPUs available for the shape of each worker node. The default value is 4. "
}
variable worker_boot_volume_vpus_per_gb {
    default     = 20
    type        = number
    description = "The number of volume performance units (VPUs) that will be applied to this volume per GB of each worker node. The default value is 20. "
}
variable worker_memory {
    default     = 16
    type        = number
    description = "The amount of memory available for the shape of each worker node, in gigabytes. The default value is 16."
}
variable worker_boot_size {
    default     = 100
    type        = number
    description = "The size of the boot volume of each worker node in GBs. The minimum value is 50 GB and the maximum value is 32,768 GB (32 TB). The default value is 100 GB."

}

variable "tenancy_ocid" {
    type        = string
    description = "The ocid of the current tenancy."
}

## Openshift infrastructure compartment
variable compartment_ocid {
    type        = string
    description = "The ocid of the compartment where you wish to create the OpenShift cluster."
}

## Openshift cluster name
variable cluster_name {
    type        = string
    description = "The name of your OpenShift cluster. It should be the same as what was specified when creating the OpenShift ISO and it should be DNS compatible."
}

variable "vcn_cidr" {
  default = "10.0.0.0/16"
  description = "The IPv4 CIDR blocks for the VCN of your OpenShift Cluster. The default value is 10.0.0.0/16. "
}
variable "private_cidr" {
  default = "10.0.16.0/20"
  description = "The IPv4 CIDR blocks for the private subnet of your OpenShift Cluster. The default value is 10.0.16.0/20. "
}
variable "public_cidr" {
  default = "10.0.0.0/20"
  description = "The IPv4 CIDR blocks for the public subnet of your OpenShift Cluster. The default value is 10.0.0.0/20. "
}

variable "openshift_image_source_uri" {
  type        = string
  description = "The OCI Object Storage URL for the OpenShift image. Before provisioning resources through this Resource Manager stack, users should upload the OpenShift image to OCI Object Storage, create a pre-authenticated requests (PAR) uri, and paste the uri to this block. For more detail regarding Object storage and PAR, please visit https://docs.oracle.com/en-us/iaas/Content/Object/Concepts/objectstorageoverview.htm and https://docs.oracle.com/en-us/iaas/Content/Object/Tasks/usingpreauthenticatedrequests.htm ."
}

variable "create_bootstrap" {
  type = bool
  default = false
  description = "create bootstrap node"
}

variable "ccm_namespace" {
  type = string
  default = "oci-cloud-controller-manager"
  description = "OCI Cloud Controller Manager namespace used to build the secret configuration."
}

variable "ccm_config_output_filename" {
  type = string
  default = "tf-output.oci_ccm_config_secret.yaml"
  description = "OCI Cloud Controller Manager secret manifest file name."
}

variable "compartment_dns_ocid" {
  type = string
  description = "custom DNS name to setup public DNS address"
}

# Provider
provider oci {
	region = var.home_region
}

locals {
  all_protocols = "all"
  anywhere      = "0.0.0.0/0"
  create_openshift_instance_pools = true
  pool_formatter_id = join("", ["$", "{launchCount}"])
}

data oci_identity_availability_domain availability_domain {
  compartment_id = var.compartment_ocid
  ad_number      = "1"
}

##Defined tag namespace. Use to mark instance roles and configure instance policy
resource oci_identity_tag_namespace openshift_tags {
  compartment_id = var.compartment_ocid
  description    = "Used for track openshift related resources and policies"
  is_retired     = "false"
  name           = "openshift-${var.cluster_name}"
}

resource oci_identity_tag openshift_instance_role {
  description      = "Describe instance role inside OpenShift cluster"
  is_cost_tracking = "false"
  is_retired       = "false"
  name             = "instance-role"
  tag_namespace_id = oci_identity_tag_namespace.openshift_tags.id
  validator {
    validator_type = "ENUM"
    values         = [
      "master",
      "worker",
    ]
  }
}

data "oci_core_compute_global_image_capability_schemas" "image_capability_schemas" {
}

locals {
  global_image_capability_schemas = data.oci_core_compute_global_image_capability_schemas.image_capability_schemas.compute_global_image_capability_schemas
  image_schema_data               = {
    "Compute.Firmware" = "{\"values\": [\"BIOS\",\"UEFI_64\"],\"defaultValue\": \"UEFI_64\",\"descriptorType\": \"enumstring\",\"source\": \"IMAGE\"}"
  }
}

resource "oci_core_image" "openshift_image" {
  count          = local.create_openshift_instance_pools ? 1 : 0
  compartment_id = var.compartment_ocid
  display_name   = var.cluster_name
  launch_mode    = "PARAVIRTUALIZED"

  image_source_details {
    source_type = "objectStorageUri"
    source_uri = var.openshift_image_source_uri
    
    source_image_type = "QCOW2"
  }
}

resource "oci_core_shape_management" "imaging_master_shape" {
  count          = local.create_openshift_instance_pools ? 1 : 0
  compartment_id = var.compartment_ocid
  image_id       = oci_core_image.openshift_image[0].id
  shape_name     = var.master_shape
}

resource "oci_core_shape_management" "imaging_worker_shape" {
  count          = local.create_openshift_instance_pools ? 1 : 0
  compartment_id = var.compartment_ocid
  image_id       = oci_core_image.openshift_image[0].id
  shape_name     = var.worker_shape
}

resource "oci_core_compute_image_capability_schema" "openshift_image_capability_schema" {
  count                                               = local.create_openshift_instance_pools ? 1 : 0
  compartment_id                                      = var.compartment_ocid
  compute_global_image_capability_schema_version_name = local.global_image_capability_schemas[0].current_version_name
  image_id                                            = oci_core_image.openshift_image[0].id
  schema_data                                         = local.image_schema_data
}

##Define network
resource oci_core_vcn openshift_vcn {
  cidr_blocks = [
    var.vcn_cidr,
  ]
  compartment_id = var.compartment_ocid
  display_name   = var.cluster_name
  #dns_label      = trim(var.cluster_name, "-")
  dns_label      = "oci"
}

resource "oci_core_internet_gateway" "internet_gateway" {
  compartment_id = var.compartment_ocid
  display_name   = "InternetGateway"
  vcn_id         = oci_core_vcn.openshift_vcn.id
}

resource "oci_core_nat_gateway" "nat_gateway" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.openshift_vcn.id
  display_name   = "NatGateway"
}

data "oci_core_services" "oci_services" {
  filter {
    name   = "name"
    values = ["All .* Services In Oracle Services Network"]
    regex  = true
  }
}

resource "oci_core_service_gateway" "service_gateway" {
  #Required
  compartment_id = var.compartment_ocid

  services {
    service_id = data.oci_core_services.oci_services.services[0]["id"]
  }

  vcn_id = oci_core_vcn.openshift_vcn.id

  display_name = "ServiceGateway"
}

resource "oci_core_route_table" "public_routes" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.openshift_vcn.id
  display_name   = "public"

  route_rules {
        destination       = local.anywhere
        destination_type  = "CIDR_BLOCK"
        network_entity_id = oci_core_internet_gateway.internet_gateway.id
  }
}

resource "oci_core_route_table" "private_routes" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.openshift_vcn.id
  display_name   = "private"

  route_rules {
        destination       = local.anywhere
        destination_type  = "CIDR_BLOCK"
        network_entity_id = oci_core_nat_gateway.nat_gateway.id
  }
  route_rules {
        destination       = data.oci_core_services.oci_services.services[0]["cidr_block"]
        destination_type  = "SERVICE_CIDR_BLOCK"
        network_entity_id = oci_core_service_gateway.service_gateway.id
  }
}

resource "oci_core_security_list" "private" {
  compartment_id = var.compartment_ocid
  display_name   = "private"
  vcn_id         = oci_core_vcn.openshift_vcn.id

  ingress_security_rules {
        source   = var.vcn_cidr
        protocol = local.all_protocols
  }
  egress_security_rules {
    destination = local.anywhere
    protocol    = local.all_protocols
  }
}

resource "oci_core_security_list" "public" {
  compartment_id = var.compartment_ocid
  display_name   = "public"
  vcn_id         = oci_core_vcn.openshift_vcn.id

  ingress_security_rules {
        source   = var.vcn_cidr
        protocol = local.all_protocols
  }
  ingress_security_rules {
        source   = local.anywhere
        protocol = "6"
        tcp_options {
            min = 22
            max = 22
        }
  }
  egress_security_rules {
    destination = local.anywhere
    protocol    = local.all_protocols
  }
}

resource "oci_core_subnet" "private" {
  cidr_block     = var.private_cidr
  display_name   = "private"
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.openshift_vcn.id
  route_table_id = oci_core_route_table.private_routes.id

  security_list_ids = [
    oci_core_security_list.private.id,
  ]

  dns_label                  = "int"
  prohibit_public_ip_on_vnic = true
}

resource "oci_core_subnet" "public" {
  cidr_block     = var.public_cidr
  display_name   = "public"
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.openshift_vcn.id
  route_table_id = oci_core_route_table.public_routes.id

  security_list_ids = [
    oci_core_security_list.public.id,
  ]

  dns_label                  = "public"
  prohibit_public_ip_on_vnic = false
}

resource "oci_core_network_security_group" "cluster_lb_nsg" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.openshift_vcn.id
  display_name   = "cluster-lb-nsg"
}

resource "oci_core_network_security_group_security_rule" "cluster_lb_nsg_rule_1" {
  network_security_group_id = oci_core_network_security_group.cluster_lb_nsg.id
  direction                 = "EGRESS"
  destination               = local.anywhere
  protocol                  = local.all_protocols
}

resource "oci_core_network_security_group_security_rule" "cluster_lb_nsg_rule_2" {
  network_security_group_id = oci_core_network_security_group.cluster_lb_nsg.id
  protocol                  = "6"
  direction                 = "INGRESS"
  source                    = local.anywhere
  tcp_options {
    destination_port_range {
      min = 6443
      max = 6443
    }
  }
}

resource "oci_core_network_security_group_security_rule" "cluster_lb_nsg_rule_3" {
  network_security_group_id = oci_core_network_security_group.cluster_lb_nsg.id
  protocol                  = "6"
  direction                 = "INGRESS"
  source                    = local.anywhere
  tcp_options {
    destination_port_range {
      min = 22623
      max = 22623
    }
  }
}

resource "oci_core_network_security_group_security_rule" "cluster_lb_nsg_rule_4" {
  network_security_group_id = oci_core_network_security_group.cluster_lb_nsg.id
  protocol                  = "6"
  direction                 = "INGRESS"
  source                    = local.anywhere
  tcp_options {
    destination_port_range {
      min = 80
      max = 80
    }
  }
}

resource "oci_core_network_security_group_security_rule" "cluster_lb_nsg_rule_5" {
  network_security_group_id = oci_core_network_security_group.cluster_lb_nsg.id
  protocol                  = "6"
  direction                 = "INGRESS"
  source                    = local.anywhere
  tcp_options {
    destination_port_range {
      min = 443
      max = 443
    }
  }
}

resource "oci_core_network_security_group_security_rule" "cluster_lb_nsg_rule_6" {
  network_security_group_id = oci_core_network_security_group.cluster_lb_nsg.id
  protocol                  = local.all_protocols
  direction                 = "INGRESS"
  source                    = var.vcn_cidr
}

resource "oci_core_network_security_group" "cluster_controlplane_nsg" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.openshift_vcn.id
  display_name   = "cluster-controlplane-nsg"
}

resource "oci_core_network_security_group_security_rule" "cluster_controlplane_nsg_rule_1" {
  network_security_group_id = oci_core_network_security_group.cluster_controlplane_nsg.id
  direction                 = "EGRESS"
  destination               = local.anywhere
  protocol                  = local.all_protocols
}

resource "oci_core_network_security_group_security_rule" "cluster_controlplane_nsg_2" {
  network_security_group_id = oci_core_network_security_group.cluster_controlplane_nsg.id
  protocol                  = local.all_protocols
  direction                 = "INGRESS"
  source                    = var.vcn_cidr
}

resource "oci_core_network_security_group" "cluster_compute_nsg" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.openshift_vcn.id
  display_name   = "cluster-compute-nsg"
}

resource "oci_core_network_security_group_security_rule" "cluster_compute_nsg_rule_1" {
  network_security_group_id = oci_core_network_security_group.cluster_compute_nsg.id
  direction                 = "EGRESS"
  destination               = local.anywhere
  protocol                  = local.all_protocols
}

resource "oci_core_network_security_group_security_rule" "cluster_compute_nsg_2" {
  network_security_group_id = oci_core_network_security_group.cluster_compute_nsg.id
  protocol                  = local.all_protocols
  direction                 = "INGRESS"
  source                    = var.vcn_cidr
}

#
# Load Balancer
#

resource "oci_network_load_balancer_network_load_balancer" "openshift_lb" {
  compartment_id             = var.compartment_ocid
  subnet_id                  = oci_core_subnet.public.id
  display_name               = "${var.cluster_name}"
  is_private                 = false
  network_security_group_ids = [oci_core_network_security_group.cluster_lb_nsg.id]
}

locals {
  lb_private_addr = element([
    for address in oci_network_load_balancer_network_load_balancer.openshift_lb.ip_addresses :address 
    if address.is_public == false
], 0).ip_address
  lb_public_addr = element([
    for address in oci_network_load_balancer_network_load_balancer.openshift_lb.ip_addresses :address
    if address.is_public == true
  ], 0).ip_address
}

resource "oci_network_load_balancer_backend_set" "openshift_cluster_api_backend" {
    health_checker {
        protocol    = "HTTPS"
        port        = 6443
        return_code = 200
        url_path    = "/readyz"
    }
    name                     = "openshift_cluster_api_backend"
    network_load_balancer_id = oci_network_load_balancer_network_load_balancer.openshift_lb.id
    policy                   = "FIVE_TUPLE"
    is_preserve_source       = false
    depends_on               = [oci_network_load_balancer_network_load_balancer.openshift_lb]
}

resource "oci_network_load_balancer_listener" "openshift_cluster_api" {
    default_backend_set_name = oci_network_load_balancer_backend_set.openshift_cluster_api_backend.name
    name                     = "openshift_cluster_api"
    network_load_balancer_id = oci_network_load_balancer_network_load_balancer.openshift_lb.id
    port                     = 6443
    protocol                 = "TCP"
    depends_on               = [oci_network_load_balancer_backend_set.openshift_cluster_api_backend]
}

resource "oci_network_load_balancer_backend_set" "openshift_cluster_ingress_http_backend" {
    health_checker {
        protocol = "TCP"
        port     = 80
    }
    name                     = "openshift_cluster_ingress_http_backend"
    network_load_balancer_id = oci_network_load_balancer_network_load_balancer.openshift_lb.id
    policy                   = "FIVE_TUPLE"
    is_preserve_source       = false
    depends_on               = [oci_network_load_balancer_listener.openshift_cluster_api]
}

resource "oci_network_load_balancer_listener" "openshift_cluster_ingress_http" {
    default_backend_set_name = oci_network_load_balancer_backend_set.openshift_cluster_ingress_http_backend.name
    name                     = "openshift_cluster_ingress_http"
    network_load_balancer_id = oci_network_load_balancer_network_load_balancer.openshift_lb.id
    port                     = 80
    protocol                 = "TCP"
    depends_on               = [oci_network_load_balancer_backend_set.openshift_cluster_ingress_http_backend]
}

resource "oci_network_load_balancer_backend_set" "openshift_cluster_ingress_https_backend" {
    health_checker {
        protocol = "TCP"
        port     = 443
    }
    name                     = "openshift_cluster_ingress_https_backend"
    network_load_balancer_id = oci_network_load_balancer_network_load_balancer.openshift_lb.id
    policy                   = "FIVE_TUPLE"
    is_preserve_source       = false
    depends_on               = [oci_network_load_balancer_listener.openshift_cluster_ingress_http]
}

resource "oci_network_load_balancer_listener" "openshift_cluster_ingress_https" {
    default_backend_set_name = oci_network_load_balancer_backend_set.openshift_cluster_ingress_https_backend.name
    name                     = "openshift_cluster_ingress_https"
    network_load_balancer_id = oci_network_load_balancer_network_load_balancer.openshift_lb.id
    port                     = 443
    protocol                 = "TCP"
    depends_on               = [oci_network_load_balancer_backend_set.openshift_cluster_ingress_https_backend]
}

resource "oci_network_load_balancer_backend_set" "openshift_cluster_infra-mcs_backend" {
    health_checker {
        protocol    = "HTTPS"
        port        = 22623
        url_path    = "/healthz"
        return_code = 200
    }
    name                     = "openshift_cluster_infra-mcs_backend"
    network_load_balancer_id = oci_network_load_balancer_network_load_balancer.openshift_lb.id
    policy                   = "FIVE_TUPLE"
    is_preserve_source       = false
    depends_on               = [oci_network_load_balancer_listener.openshift_cluster_ingress_https]
}

resource "oci_network_load_balancer_listener" "openshift_cluster_infra-mcs" {
    default_backend_set_name = oci_network_load_balancer_backend_set.openshift_cluster_infra-mcs_backend.name
    name                     = "openshift_cluster_infra-mcs"
    network_load_balancer_id = oci_network_load_balancer_network_load_balancer.openshift_lb.id
    port                     = 22623
    protocol                 = "TCP"
    depends_on               = [oci_network_load_balancer_backend_set.openshift_cluster_infra-mcs_backend]
}

#
# IAM
#

resource "oci_identity_dynamic_group" "openshift_master_nodes" {
    compartment_id = var.tenancy_ocid
    description    = "OpenShift master nodes" 
    matching_rule  = "all {instance.compartment.id='${var.compartment_ocid}', tag.openshift-${var.cluster_name}.instance-role.value='master'}"
    name           = "${var.cluster_name}_master_nodes"
}

resource "oci_identity_policy" "openshift_master_nodes" {
    compartment_id = var.tenancy_ocid
    description    = "OpenShift master nodes instance principal"
    name           = "${var.cluster_name}_master_nodes"
    statements     = [
        "Allow dynamic-group ${oci_identity_dynamic_group.openshift_master_nodes.name} to manage volume-family in compartment id ${var.compartment_ocid}",
        "Allow dynamic-group ${oci_identity_dynamic_group.openshift_master_nodes.name} to manage instance-family in compartment id ${var.compartment_ocid}",
        "Allow dynamic-group ${oci_identity_dynamic_group.openshift_master_nodes.name} to manage security-lists in compartment id ${var.compartment_ocid}",
        "Allow dynamic-group ${oci_identity_dynamic_group.openshift_master_nodes.name} to use virtual-network-family in compartment id ${var.compartment_ocid}",
        "Allow dynamic-group ${oci_identity_dynamic_group.openshift_master_nodes.name} to manage load-balancers in compartment id ${var.compartment_ocid}",
    ]
}

resource "oci_identity_dynamic_group" "openshift_worker_nodes" {
  compartment_id = var.tenancy_ocid
  description    = "OpenShift worker nodes"
  matching_rule  = "all {instance.compartment.id='${var.compartment_ocid}', tag.openshift-${var.cluster_name}.instance-role.value='worker'}"
  name           = "${var.cluster_name}_worker_nodes"
}

#
# DNS
#

resource oci_dns_zone openshift {
  compartment_id = var.compartment_ocid
  name           = var.zone_dns
  scope          = "PRIVATE"
  view_id        = data.oci_dns_resolver.dns_resolver.default_view_id
  zone_type      = "PRIMARY"
  depends_on     = [oci_core_subnet.private]
}

resource oci_dns_rrset openshift_api {
  domain = "api.${var.cluster_name}.${var.zone_dns}"
  items {
    domain = "api.${var.cluster_name}.${var.zone_dns}"
    rdata  = local.lb_private_addr
    rtype  = "A"
    ttl    = "30"
  }
  rtype           = "A"
  zone_name_or_id = oci_dns_zone.openshift.id
}

resource oci_dns_rrset openshift_apps {
  domain = "*.apps.${var.cluster_name}.${var.zone_dns}"
  items {
    domain = "*.apps.${var.cluster_name}.${var.zone_dns}"
    rdata  = local.lb_private_addr
    rtype  = "A"
    ttl    = "30"
  }
  rtype           = "A"
  zone_name_or_id = oci_dns_zone.openshift.id
}

resource oci_dns_rrset openshift_api_int {
  domain = "api-int.${var.cluster_name}.${var.zone_dns}"
  items {
    domain = "api-int.${var.cluster_name}.${var.zone_dns}"
    rdata  = local.lb_private_addr
    rtype  = "A"
    ttl    = "30"
  }
  rtype           = "A"
  zone_name_or_id = oci_dns_zone.openshift.id
}

# resource oci_dns_zone openshift_public {
#   compartment_id = var.compartment_dns_ocid
#   name           = var.zone_dns
#   scope          = "GLOBAL"
#   zone_type      = "PRIMARY"
# }

resource oci_dns_rrset openshift_public_api {
  domain = "api.${var.cluster_name}.${var.zone_dns}"
  items {
    domain = "api.${var.cluster_name}.${var.zone_dns}"
    rdata  = local.lb_public_addr
    rtype  = "A"
    ttl    = "30"
  }
  rtype           = "A"
  zone_name_or_id = var.zone_dns
  scope = "GLOBAL"
  compartment_id = "${var.compartment_dns_ocid}"
}

resource oci_dns_rrset openshift_public_apps {
  domain = "*.apps.${var.cluster_name}.${var.zone_dns}"
  items {
    domain = "*.apps.${var.cluster_name}.${var.zone_dns}"
    rdata  = local.lb_public_addr
    rtype  = "A"
    ttl    = "30"
  }
  rtype           = "A"
  zone_name_or_id = var.zone_dns
  scope = "GLOBAL"
  compartment_id = "${var.compartment_dns_ocid}"
}

resource "time_sleep" "wait_180_seconds" {
  depends_on = [oci_core_vcn.openshift_vcn]
  create_duration = "180s"
}

data "oci_core_vcn_dns_resolver_association" "dns_resolver_association" {
  vcn_id     = oci_core_vcn.openshift_vcn.id
  depends_on = [time_sleep.wait_180_seconds]
}

data "oci_dns_resolver" "dns_resolver" {
  depends_on = [
    data.oci_core_vcn_dns_resolver_association.dns_resolver_association
  ]
  resolver_id = data.oci_core_vcn_dns_resolver_association.dns_resolver_association.dns_resolver_id
  scope       = "PRIVATE"
}

#
# Compute
#

resource oci_core_instance_configuration master_node_config {
  count          = local.create_openshift_instance_pools ? 1 : 0
  compartment_id = var.compartment_ocid
  display_name   = "${var.cluster_name}-master"
  instance_details {
    instance_type = "compute"
    launch_details {
      availability_domain = data.oci_identity_availability_domain.availability_domain.name
      compartment_id      = var.compartment_ocid
      create_vnic_details {
        assign_private_dns_record = "true"
        assign_public_ip          = "false"
        nsg_ids                   = [
          oci_core_network_security_group.cluster_controlplane_nsg.id,
        ]
        subnet_id = oci_core_subnet.private.id
      }
      defined_tags = {
        "openshift-${var.cluster_name}.instance-role" = "master"
      }
      shape = var.master_shape
      shape_config {
        memory_in_gbs = var.master_memory
        ocpus         = var.master_ocpu
      }
      source_details {
        boot_volume_size_in_gbs = var.master_boot_size
        boot_volume_vpus_per_gb = var.master_boot_volume_vpus_per_gb
        image_id                = oci_core_image.openshift_image[0].id
        source_type             = "image"
      }
      metadata = {
        user_data = base64encode(data.local_file.master_ign.content)
      }
    }
  }
}

resource oci_core_instance_pool master_nodes {
  count                           = local.create_openshift_instance_pools ? 1 : 0
  compartment_id                  = var.compartment_ocid
  display_name                    = "${var.cluster_name}-master"
  instance_configuration_id       = oci_core_instance_configuration.master_node_config[0].id
  size                            = var.master_count
  instance_display_name_formatter = "${var.cluster_name}-master-${local.pool_formatter_id}"
  instance_hostname_formatter     = "${var.cluster_name}-master-${local.pool_formatter_id}"
  load_balancers {
    backend_set_name = oci_network_load_balancer_backend_set.openshift_cluster_api_backend.name
    load_balancer_id = oci_network_load_balancer_network_load_balancer.openshift_lb.id
    port             = "6443"
    vnic_selection   = "PrimaryVnic"
  }
  load_balancers {
    backend_set_name = oci_network_load_balancer_backend_set.openshift_cluster_infra-mcs_backend.name
    load_balancer_id = oci_network_load_balancer_network_load_balancer.openshift_lb.id
    port             = "22623"
    vnic_selection   = "PrimaryVnic"
  }
  load_balancers {
    backend_set_name = oci_network_load_balancer_backend_set.openshift_cluster_infra-mcs_backend_2.name
    load_balancer_id = oci_network_load_balancer_network_load_balancer.openshift_lb.id
    port             = "22624"
    vnic_selection   = "PrimaryVnic"
  }
  placement_configurations {
    availability_domain = data.oci_identity_availability_domain.availability_domain.name
    primary_subnet_id   = oci_core_subnet.private.id
  }
  depends_on = [
    oci_network_load_balancer_backend_set.openshift_cluster_api_backend,
    oci_network_load_balancer_backend_set.openshift_cluster_infra-mcs_backend,
    oci_network_load_balancer_backend_set.openshift_cluster_infra-mcs_backend_2,
    oci_core_instance_configuration.master_node_config,
  ]
}

resource oci_core_instance_configuration worker_node_config {
  count          = local.create_openshift_instance_pools ? 1 : 0
  compartment_id = var.compartment_ocid
  display_name   = "${var.cluster_name}-worker"
  instance_details {
    instance_type = "compute"
    launch_details {
      availability_domain = data.oci_identity_availability_domain.availability_domain.name
      compartment_id      = var.compartment_ocid
      create_vnic_details {
        assign_private_dns_record = "true"
        assign_public_ip          = "false"
        nsg_ids                   = [
          oci_core_network_security_group.cluster_compute_nsg.id,
        ]
        subnet_id = oci_core_subnet.private.id
      }
      defined_tags = {
        "openshift-${var.cluster_name}.instance-role" = "worker"
      }
      shape = var.worker_shape
      shape_config {
        memory_in_gbs = var.worker_memory
        ocpus         = var.worker_ocpu
      }
      source_details {
        boot_volume_size_in_gbs = var.worker_boot_size
        boot_volume_vpus_per_gb = var.worker_boot_volume_vpus_per_gb
        image_id                = oci_core_image.openshift_image[0].id
        source_type             = "image"
      }
      metadata = {
        user_data = base64encode(data.local_file.worker_ign.content)
      }
    }
  }
}

resource oci_core_instance_pool worker_nodes {
  count                     = local.create_openshift_instance_pools ? 1 : 0
  compartment_id            = var.compartment_ocid
  display_name              = "${var.cluster_name}-worker"
  instance_configuration_id = oci_core_instance_configuration.worker_node_config[0].id
  size       = var.worker_count
  instance_display_name_formatter = "${var.cluster_name}-worker-${local.pool_formatter_id}"
  instance_hostname_formatter     = "${var.cluster_name}-worker-${local.pool_formatter_id}"
  load_balancers {
    backend_set_name = oci_network_load_balancer_backend_set.openshift_cluster_ingress_https_backend.name
    load_balancer_id = oci_network_load_balancer_network_load_balancer.openshift_lb.id
    port             = "443"
    vnic_selection   = "PrimaryVnic"
  }
  load_balancers {
    backend_set_name = oci_network_load_balancer_backend_set.openshift_cluster_ingress_http_backend.name
    load_balancer_id = oci_network_load_balancer_network_load_balancer.openshift_lb.id
    port             = "80"
    vnic_selection   = "PrimaryVnic"
  }
  placement_configurations {
    availability_domain = data.oci_identity_availability_domain.availability_domain.name
    primary_subnet_id   = oci_core_subnet.private.id
  }
  depends_on = [
    oci_network_load_balancer_backend_set.openshift_cluster_ingress_https_backend,
    oci_network_load_balancer_backend_set.openshift_cluster_ingress_http_backend,
    oci_core_instance_configuration.worker_node_config,
  ]
}

output "open_shift_ln_private_addr" {
  value = local.lb_private_addr
}

output "open_shift_ln_public_addr" {
  value = local.lb_public_addr
}

output "oci_ccm_config" {
  value = <<OCICCMCONFIG
useInstancePrincipals: true
compartment: ${var.compartment_ocid}
vcn: ${oci_core_vcn.openshift_vcn.id}
loadBalancer:
  subnet1: ${oci_core_subnet.public.id}
  securityListManagementMode: Frontend
  securityLists:
    ${oci_core_subnet.public.id}: ${oci_core_security_list.public.id}
rateLimiter:
  rateLimitQPSRead: 20.0
  rateLimitBucketRead: 5
  rateLimitQPSWrite: 20.0
  rateLimitBucketWrite: 5
  OCICCMCONFIG
}

resource "local_file" "oci_ccm_config" {
  filename = "${path.module}/${var.ccm_config_output_filename}"
  content  = <<OCICCMCONFIG
---
apiVersion: v1
kind: Secret
metadata:
  name: oci-cloud-controller-manager
  namespace: ${var.ccm_namespace}
stringData:
  cloud-provider.yaml: |
    useInstancePrincipals: true
    compartment: ${var.compartment_ocid}
    vcn: ${oci_core_vcn.openshift_vcn.id}
    loadBalancer:
      subnet1: ${oci_core_subnet.public.id}
      securityListManagementMode: Frontend
      securityLists:
        ${oci_core_subnet.public.id}: ${oci_core_security_list.public.id}
    rateLimiter:
      rateLimitQPSRead: 20.0
      rateLimitBucketRead: 5
      rateLimitQPSWrite: 20.0
      rateLimitBucketWrite: 5
  OCICCMCONFIG
}

resource "oci_network_load_balancer_backend_set" "openshift_cluster_infra-mcs_backend_2" {
  health_checker {
    protocol           = "TCP"
    port               = 22624
    interval_in_millis = 10000
    timeout_in_millis  = 3000
    retries            = 3
  }
  name                     = "openshift_cluster_infra-mcs_backend_2"
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.openshift_lb.id
  policy                   = "FIVE_TUPLE"
  is_preserve_source       = false
  depends_on               = [oci_network_load_balancer_listener.openshift_cluster_infra-mcs]
}

resource "oci_network_load_balancer_listener" "openshift_cluster_infra-mcs_2" {
  default_backend_set_name = oci_network_load_balancer_backend_set.openshift_cluster_infra-mcs_backend_2.name
  name                     = "openshift_cluster_infra-mcs_2"
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.openshift_lb.id
  port                     = 22624
  protocol                 = "TCP"
  depends_on               = [oci_network_load_balancer_backend_set.openshift_cluster_infra-mcs_backend_2]
}

resource "oci_core_network_security_group_security_rule" "cluster_lb_nsg_rule_7" {
  network_security_group_id = oci_core_network_security_group.cluster_lb_nsg.id
  protocol                  = "6"
  direction                 = "INGRESS"
  source                    = local.anywhere
  tcp_options {
    destination_port_range {
      min = 22624
      max = 22624
    }
  }
}


## UPI specific

data "local_file" "bootstrap_ign" {
  count    = var.create_bootstrap ? 1 : 0
  filename = "${path.module}/bootstrap-upi.ign"
}

data "local_file" "master_ign" {
  filename = "${path.module}/master.ign"
}

data "local_file" "worker_ign" {
  filename = "${path.module}/worker.ign"
}

resource oci_core_instance_configuration bootstrap_node_config {
  count          = var.create_bootstrap ? 1 : 0
  compartment_id = var.compartment_ocid
  display_name   = "${var.cluster_name}-bootstrap"
  instance_details {
    instance_type = "compute"
    launch_details {
      availability_domain = data.oci_identity_availability_domain.availability_domain.name
      compartment_id      = var.compartment_ocid
      create_vnic_details {
        assign_private_dns_record = "true"
        assign_public_ip          = "true"
        nsg_ids                   = [
          oci_core_network_security_group.cluster_controlplane_nsg.id,
        ]
        subnet_id = oci_core_subnet.public.id
      }
      defined_tags = {
        "openshift-${var.cluster_name}.instance-role" = "master"
      }
      shape = var.master_shape
      shape_config {
        memory_in_gbs = var.master_memory
        ocpus         = var.master_ocpu
      }
      source_details {
        boot_volume_size_in_gbs = var.master_boot_size
        boot_volume_vpus_per_gb = var.master_boot_volume_vpus_per_gb
        image_id                = oci_core_image.openshift_image[0].id
        source_type             = "image"
      }
      metadata = {
        user_data = base64encode(data.local_file.bootstrap_ign[0].content)
      }
    }
  }
}

resource oci_core_instance_pool bootstrap_node {
  count                     = var.create_bootstrap ? 1 : 0
  compartment_id            = var.compartment_ocid
  display_name              = "${var.cluster_name}-bootstrap"
  instance_configuration_id = oci_core_instance_configuration.bootstrap_node_config[0].id
  size                      = 1
  instance_display_name_formatter = "${var.cluster_name}-bootstrap-${local.pool_formatter_id}"
  instance_hostname_formatter = "${var.cluster_name}-bootstrap-${local.pool_formatter_id}"
  load_balancers {
    backend_set_name = oci_network_load_balancer_backend_set.openshift_cluster_api_backend.name
    load_balancer_id = oci_network_load_balancer_network_load_balancer.openshift_lb.id
    port             = "6443"
    vnic_selection   = "PrimaryVnic"
  }
  load_balancers {
    backend_set_name = oci_network_load_balancer_backend_set.openshift_cluster_infra-mcs_backend.name
    load_balancer_id = oci_network_load_balancer_network_load_balancer.openshift_lb.id
    port             = "22623"
    vnic_selection   = "PrimaryVnic"
  }
  load_balancers {
    backend_set_name = oci_network_load_balancer_backend_set.openshift_cluster_infra-mcs_backend_2.name
    load_balancer_id = oci_network_load_balancer_network_load_balancer.openshift_lb.id
    port             = "22624"
    vnic_selection   = "PrimaryVnic"
  }
  placement_configurations {
    availability_domain = data.oci_identity_availability_domain.availability_domain.name
    primary_subnet_id   = oci_core_subnet.public.id
  }
  depends_on = [
    oci_network_load_balancer_backend_set.openshift_cluster_api_backend,
    oci_network_load_balancer_backend_set.openshift_cluster_infra-mcs_backend,
    oci_network_load_balancer_backend_set.openshift_cluster_infra-mcs_backend_2,
    oci_core_instance_configuration.bootstrap_node_config,
  ]
}