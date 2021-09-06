terraform {
  required_version = ">= 0.15"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=2.74.0"
    }
  }
}
provider "azurerm" {
  features {}
}
#
# Locals
#
# custom data script for VM customization - install nodejs and run a HTTP Server to respond to requests
locals {
  custom_data = <<CUSTOM_DATA
#!/bin/bash
sudo dnf -y module install nodejs/minimal
sudo systemctl stop firewalld 
sudo systemctl disable firewalld
sudo cat <<EOF > webserver.js
var http = require('http');
http.createServer(function (req, res) {
  res.writeHead(200, {'Content-Type': 'text/html'});
  res.write('Hello '+req.url);
  res.end();
}).listen(80);
EOF
sudo node webserver.js &
CUSTOM_DATA
}
#
# Resource Group
#
resource "azurerm_resource_group" "this" {
  name     = "${var.tenant}-rg-agw-${var.region.code}"
  location = var.region.name
}
#
# Virtual network and Subnets
#
resource "azurerm_virtual_network" "this" {
  name                = "${var.tenant}-vnet"
  address_space       = ["${var.vnet-address-space}"]
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  subnet {
    name           = "frontend"
    address_prefix = var.frontend-subnet
  }
  subnet {
    name           = "backend"
    address_prefix = var.backend-subnet
  }
}
#
# Virtual Machine NICs
#
resource "azurerm_network_interface" "vm1_nic" {
  name                = "${var.tenant}-vm1-nic"
  location            = var.region.name
  resource_group_name = azurerm_resource_group.this.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_virtual_network.this.subnet.*.id[1]
    private_ip_address_allocation = "Dynamic"
  }
}
resource "azurerm_network_interface" "vm2_nic" {
  name                = "${var.tenant}-vm2-nic"
  location            = var.region.name
  resource_group_name = azurerm_resource_group.this.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_virtual_network.this.subnet.*.id[1]
    private_ip_address_allocation = "Dynamic"
  }
}
#
# Virtual Machines - Custom app
#
resource "azurerm_linux_virtual_machine" "vm1" {
  name                            = "${var.tenant}-vm1"
  resource_group_name             = azurerm_resource_group.this.name
  location                        = var.region.name
  size                            = "Standard_B1s"
  admin_username                  = var.admin_username
  admin_password                  = var.admin_password
  disable_password_authentication = false
  custom_data                     = base64encode(local.custom_data)
  network_interface_ids           = [azurerm_network_interface.vm1_nic.id]
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "oracle"
    offer     = "oracle-linux"
    sku       = "ol84-lvm-gen2"
    version   = "latest"
  }
}
resource "azurerm_linux_virtual_machine" "vm2" {
  name                            = "${var.tenant}-vm2"
  resource_group_name             = azurerm_resource_group.this.name
  location                        = var.region.name
  size                            = "Standard_B1s"
  admin_username                  = var.admin_username
  admin_password                  = var.admin_password
  disable_password_authentication = false
  custom_data                     = base64encode(local.custom_data)
  network_interface_ids           = [azurerm_network_interface.vm2_nic.id]
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "oracle"
    offer     = "oracle-linux"
    sku       = "ol84-lvm-gen2"
    version   = "latest"
  }
}
#
# Public IP for Application Gateway
#
resource "azurerm_public_ip" "this" {
  name                = "${var.tenant}-pip-agw"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  sku                 = "Standard"
  allocation_method   = "Static"
  domain_name_label   = "${var.tenant}-agw"
}
#
# App Service Plan for function app
#
resource "azurerm_app_service_plan" "this" {
  name                = "${var.tenant}-plan-agwtest"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  kind                = "Linux"
  reserved            = true
  sku {
    tier = "Standard"
    size = "S1"
  }
}
#
# Storage Account for function app
#
resource "azurerm_storage_account" "this" {
  name                     = "${var.tenant}stfunc${var.region.code}"
  resource_group_name      = azurerm_resource_group.this.name
  location                 = azurerm_resource_group.this.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  network_rules {
    default_action = "Deny"
  }
}
#
# Function app (node runtime) - default app
#
resource "azurerm_function_app" "this" {
  name                       = "${var.tenant}-func-node-${var.region.code}"
  location                   = azurerm_resource_group.this.location
  resource_group_name        = azurerm_resource_group.this.name
  app_service_plan_id        = azurerm_app_service_plan.this.id
  storage_account_name       = azurerm_storage_account.this.name
  storage_account_access_key = azurerm_storage_account.this.primary_access_key
  os_type                    = "linux"
  version                    = "~3"
  app_settings = {
    FUNCTIONS_WORKER_RUNTIME = "node"
  }
  site_config {
    always_on = true
  }
}
#
# Application Gateway (Public)
#
resource "azurerm_application_gateway" "this" {
  enable_http2        = true
  location            = azurerm_resource_group.this.location
  name                = "${var.tenant}-agw-public-${var.region.code}"
  resource_group_name = azurerm_resource_group.this.name
  tags                = {}
  zones               = []
  sku {
    capacity = 0
    name     = "WAF_v2"
    tier     = "WAF_v2"
  }
  autoscale_configuration {
    max_capacity = 10
    min_capacity = 0
  }
  gateway_ip_configuration {
    name      = "${var.tenant}-agw-public-ipconfig"
    subnet_id = azurerm_virtual_network.this.subnet.*.id[0]
  }
  ###############   FRONTEND  ###############
  frontend_ip_configuration {
    name                 = "${var.tenant}-agw-public-feip"
    public_ip_address_id = azurerm_public_ip.this.id
  }
  frontend_port {
    name = "port_80"
    port = 80
  }
  frontend_port {
    name = "port_8080"
    port = 8080
  }
  ###############   HTTP LISTENER  ###############  
  http_listener {
    name                           = "lsnr-myapp"
    frontend_ip_configuration_name = "${var.tenant}-agw-public-feip"
    frontend_port_name             = "port_80"
    host_name                      = "cg-agw.canadacentral.cloudapp.azure.com"
    protocol                       = "Http"
  }
  http_listener {
    name                           = "lsnr-redirect"
    frontend_ip_configuration_name = "${var.tenant}-agw-public-feip"
    frontend_port_name             = "port_8080"
    protocol                       = "Http"
  }
  ###############   BACKEND ADDRESS POOL  ###############  
  backend_address_pool {
    fqdns = [format("%s", azurerm_function_app.this.default_hostname)]
    name  = "pool-default"
  }
  backend_address_pool {
    ip_addresses = [format("%s", azurerm_network_interface.vm1_nic.private_ip_address), format("%s", azurerm_network_interface.vm2_nic.private_ip_address)]
    name         = "pool-custom"
  }
  ###############   HEALTH PROBE  ###############  
  probe {
    name                                      = "probe-default"
    protocol                                  = "Https"
    path                                      = "/"
    pick_host_name_from_backend_http_settings = true
    interval                                  = "3"
    timeout                                   = "2"
    unhealthy_threshold                       = "3"
    match {
      body        = "up and running"
      status_code = ["200"]
    }
  }
  probe {
    name                                      = "probe-custom"
    protocol                                  = "Http"
    path                                      = "/"
    pick_host_name_from_backend_http_settings = true
    interval                                  = "3"
    timeout                                   = "2"
    unhealthy_threshold                       = "3"
    match {
      status_code = ["200"]
    }
  }
  ###############   BACKEND HTTP SETTING  ###############  
  backend_http_settings {
    cookie_based_affinity               = "Disabled"
    name                                = "http-default"
    pick_host_name_from_backend_address = true
    port                                = 443
    protocol                            = "Https"
    request_timeout                     = 20
    trusted_root_certificate_names      = []
    probe_name                          = "probe-default"
  }
  backend_http_settings {
    cookie_based_affinity               = "Disabled"
    name                                = "http-custom"
    pick_host_name_from_backend_address = true
    port                                = 80
    protocol                            = "Http"
    request_timeout                     = 20
    trusted_root_certificate_names      = []
    probe_name                          = "probe-custom"
  }
  ###############   REDIRECT  ###############  
  redirect_configuration {
    name                 = "redirect-API-v3"
    include_path         = false
    include_query_string = false
    redirect_type        = "Permanent"
    target_url           = "https://docs.readthedocs.io/en/stable/api/v3.html"
  }
  redirect_configuration {
    name                 = "redirect-8080"
    include_path         = false
    include_query_string = false
    redirect_type        = "Permanent"
    target_url           = format("http://%s.canadacentral.cloudapp.azure.com", azurerm_public_ip.this.domain_name_label)
  }
  ###############   URL PATH MAP  ###############  
  url_path_map {
    name                               = "path-map-myapp"
    default_backend_address_pool_name  = "pool-default"
    default_backend_http_settings_name = "http-default"
    path_rule {
      name                       = "API-v1-v2"
      paths                      = ["/v1/*", "/v2/*"]
      backend_address_pool_name  = "pool-custom"
      backend_http_settings_name = "http-custom"
    }
    path_rule {
      name                        = "API-v3"
      paths                       = ["/v3/*"]
      redirect_configuration_name = "redirect-API-v3"
    }
  }
  ###############   REQUEST ROUTING RULE  ###############  
  request_routing_rule {
    name               = "rule-myapp"
    rule_type          = "PathBasedRouting"
    http_listener_name = "lsnr-myapp"
    url_path_map_name  = "path-map-myapp"
  }
  request_routing_rule {
    name                        = "rule-redirect"
    rule_type                   = "Basic"
    http_listener_name          = "lsnr-redirect"
    redirect_configuration_name = "redirect-8080"
  }
}