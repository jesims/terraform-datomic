variable "env" {
  description = "Environment"
}

variable "vpc_name" {
  description = "Existing VPC Name"
}

variable "resource_prefix" {
  description = "Prefix to be applied to all resources"
  default     = ""
}

variable "dynamo_table" {
  description = "Prefix to be applied to all resources"
  default     = ""
}

variable "datomic_license" {
  description = "Datomic license key"
}

variable "datomic_version" {
  description = "Datomic version number"
}

variable "peer_role_name" {
  description = "The Peer Role name"
}

variable "region" {
  description = "The region to deploy into"
}

variable "transactor_instance_type" {
  description = "Instance type and size"
}

variable "transactor_instance_virtualization_type" {
  description = "Virtualization type for the instance."
  default     = "hvm"
}

variable "transactors" {
  description = "Number of transactors to run"
  default     = "1"
}

variable "subnet_name" {
  description = "The Subnet name to place the transactors in"
}

variable "transactor_deploy_bucket" {
  default = "deploy-a0dbc565-faf2-4760-9b7e-29a8e45f428e"
}

variable "transactor_xmx" {
  description = "The maximum size, in bytes, of the memory allocation pool. This value must a multiple of 1024 greater than 2MB."
}

variable "transactor_java_opts" {
  description = "JAVA_OPTS to pass to Datomic (It's unclear what this actually does)"
}

variable "transactor_memory_index_max" {
  description = "Apply back pressure to let indexing catch up"
}

variable "transactor_memory_index_threshold" {
  description = "Start building index when this is reached"
  default     = "16m"
}

variable "transactor_object_cache_max" {
  description = "Size of the object cache"
}
