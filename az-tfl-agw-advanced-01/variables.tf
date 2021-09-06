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
  description = "(Optional) VNet address spaces"
  default     = "10.100.0.0/16"
}
variable "frontend-subnet" {
  type        = string
  description = "(Optional) Subnet used by the Application Gateway"
  default     = "10.100.0.0/24"
}
variable "backend-subnet" {
  type        = string
  description = "(Optional) Subnet used by the backend VMs"
  default     = "10.100.1.0/24"
}
variable "admin_username" {
  type        = string
  description = "(Required) Username for the admin user for SSH access"
}
variable "admin_password" {
  type        = string
  description = "(Required) Password for the admin user for SSH access"
  sensitive   = true
}
