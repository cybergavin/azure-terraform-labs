output "TEST" {
  value = format("Allow some time for the function app to start and then access the function app default homepage behind the application gateway via http://%s.canadacentral.cloudapp.azure.com", azurerm_public_ip.this.domain_name_label)
}