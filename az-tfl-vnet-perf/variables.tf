variable "prefix" {
  type        = string
  description = "(Required) Prefix to be used in names of all resources"
}
variable "location" {
  type        = string
  description = "(Required) Location of all resources and resource group"
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