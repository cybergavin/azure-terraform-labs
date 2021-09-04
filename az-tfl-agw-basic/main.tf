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
# Resource Group
#
resource "azurerm_resource_group" "this" {
  name     = "${var.tenant}-rg-agw-${var.region.code}"
  location = var.region.name
}
#
# Virtual network
#
resource "azurerm_virtual_network" "this" {
  name                = "${var.tenant}-network"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  address_space       = ["${var.vnet-address-space}"]
}
#
# Subnet
#
resource "azurerm_subnet" "frontend" {
  name                                           = "frontend"
  resource_group_name                            = azurerm_resource_group.this.name
  virtual_network_name                           = azurerm_virtual_network.this.name
  address_prefixes                               = ["${var.subnet-address-space}"]
  enforce_private_link_endpoint_network_policies = true
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
# Function app (node runtime)
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
    subnet_id = azurerm_subnet.frontend.id
  }
  frontend_ip_configuration {
    name                 = "${var.tenant}-agw-public-feip"
    public_ip_address_id = azurerm_public_ip.this.id
  }
  frontend_port {
    name = "port_80"
    port = 80
  }
  http_listener {
    frontend_ip_configuration_name = "${var.tenant}-agw-public-feip"
    frontend_port_name             = "port_80"
    name                           = "lsnr-myapp"
    protocol                       = "Http"
    require_sni                    = false
  }
  backend_address_pool {
    fqdns = [format("%s", azurerm_function_app.this.default_hostname)]
    name  = "pool-myapp"
  }
  probe {
    name                                      = "probe-myapp"
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
  backend_http_settings {
    cookie_based_affinity               = "Disabled"
    name                                = "http-myapp"
    pick_host_name_from_backend_address = true
    port                                = 443
    protocol                            = "Https"
    request_timeout                     = 20
    trusted_root_certificate_names      = []
    probe_name                          = "probe-myapp"
  }
  request_routing_rule {
    name                       = "rule-myapp"
    rule_type                  = "Basic"
    http_listener_name         = "lsnr-myapp"
    backend_address_pool_name  = "pool-myapp"
    backend_http_settings_name = "http-myapp"
  }
}