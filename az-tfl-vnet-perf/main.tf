# cybergav.in - 3rd July 2021
# USE-CASE: Test network latency between endpoints in the same VNet. The VM SKU and settings will have a bearing on network performance.
#
#########################################################################################################################################
#
# Terraform Provider Configuration
#
terraform {
  required_version = ">= 0.15"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=2.58.0"
    }
  }
}
provider "azurerm" {
  features {}
}
#
# Locals
#
locals {
custom_data = <<CUSTOM_DATA
#!/bin/bash
sudo dnf -y install qperf
sudo systemctl stop firewalld 
sudo systemctl disable firewalld 
CUSTOM_DATA
}
#
# Resource Group 
#
resource "azurerm_resource_group" "rg" {
  name     = "${var.prefix}-rg"
  location = var.location
}
#
# Virtual Networks and Subnets
#
resource "azurerm_virtual_network" "vnet" {
  name                = "${var.prefix}-vnet"
  address_space       = ["10.100.0.0/16"]
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet {
    name           = "${var.prefix}-snet1"
    address_prefix = "10.100.1.0/24"
  }
  subnet {
    name           = "${var.prefix}-snet2"
    address_prefix = "10.100.2.0/24"
  }
}
#
# Public IPs
#
resource "azurerm_public_ip" "pip1" {
  name                = "${var.prefix}-pip1"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  allocation_method   = "Dynamic"
}
resource "azurerm_public_ip" "pip2" {
  name                = "${var.prefix}-pip2"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  allocation_method   = "Dynamic"
}
#
# Virtual Machine NICs
#
resource "azurerm_network_interface" "vm1_nic" {
  name                = "${var.prefix}-vm1-nic"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_virtual_network.vnet.subnet.*.id[0]
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip1.id
  }
}
resource "azurerm_network_interface" "vm2_nic" {
  name                = "${var.prefix}-vm2-nic"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_virtual_network.vnet.subnet.*.id[1]
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip2.id
  }
}
#
# Virtual Machines
#
resource "azurerm_linux_virtual_machine" "vm1" {
  name                            = "${var.prefix}-vm1"
  resource_group_name             = azurerm_resource_group.rg.name
  location                        = var.location
  size                            = "Standard_B1s"
  admin_username                  = var.admin_username
  admin_password                  = var.admin_password
  disable_password_authentication = false
  custom_data                     = base64encode(local.custom_data)
  network_interface_ids = [
    azurerm_network_interface.vm1_nic.id,
  ]

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
  name                            = "${var.prefix}-vm2"
  resource_group_name             = azurerm_resource_group.rg.name
  location                        = var.location
  size                            = "Standard_B1s"
  admin_username                  = var.admin_username
  admin_password                  = var.admin_password
  disable_password_authentication = false
  custom_data                     = base64encode(local.custom_data)
  network_interface_ids = [
    azurerm_network_interface.vm2_nic.id,
  ]

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
