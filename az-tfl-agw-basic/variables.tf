variable "tenant" {
  type        = string
  description = "(Required) Tenant name"
}
variable "region" {
  type        = map(any)
  description = "(Required) Map of region"
}
variable "vnet-address-space" {
  type        = string
  description = "(Required) VNet address space"
}
variable "subnet-address-space" {
  type        = string
  description = "(Required) Subnet address space"
}
