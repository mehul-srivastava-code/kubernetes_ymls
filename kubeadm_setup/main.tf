terraform {
  required_version = ">= 1.9.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
  }
}

provider "azurerm" {
  features {}
}

# -------------------------
# Resource Group
# -------------------------
resource "azurerm_resource_group" "kubeadm_rg" {
  name     = var.azurerm_resource_group_name
  location = var.location
}

# -------------------------
# Virtual Network
# -------------------------
resource "azurerm_virtual_network" "main" {
  name                = var.vnet_name
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.kubeadm_rg.location
  resource_group_name = azurerm_resource_group.kubeadm_rg.name
}

# -------------------------
# Subnets
# -------------------------
resource "azurerm_subnet" "kubeadm_subnet" {
  for_each = var.subnet

  name                 = each.key
  resource_group_name  = azurerm_resource_group.kubeadm_rg.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [each.value]
}

# -------------------------
# Network Interfaces
# -------------------------
resource "azurerm_network_interface" "main" {
  for_each = var.network_interface_name

  name                = "${each.key}-nic"
  location            = azurerm_resource_group.kubeadm_rg.location
  resource_group_name = azurerm_resource_group.kubeadm_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.kubeadm_subnet[each.value.subnet_key].id
    private_ip_address_allocation = "Dynamic"
  }
}

# -------------------------
# Network Security Group for Control Plane (SSH only)
# -------------------------
resource "azurerm_network_security_group" "control_plane_nsg" {
  name                = "control-plane-nsg"
  location            = azurerm_resource_group.kubeadm_rg.location
  resource_group_name = azurerm_resource_group.kubeadm_rg.name

  security_rule {
    name                       = "AllowSSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowKubeAPI"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "6443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowEtcd"
    priority                   = 102
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "2379-2380"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# -------------------------
# Network Security Group for Worker Nodes (TCP only)
# -------------------------
resource "azurerm_network_security_group" "worker_nsg" {
  name                = "worker-nsg"
  location            = azurerm_resource_group.kubeadm_rg.location
  resource_group_name = azurerm_resource_group.kubeadm_rg.name

  security_rule {
    name                       = "AllowKubeletAPI"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "10250"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowNodePortServices"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "30000-32767"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# -------------------------
# NSG Association for Control Plane
# -------------------------
resource "azurerm_network_interface_security_group_association" "control_plane_assoc" {
  network_interface_id      = azurerm_network_interface.main["master"].id
  network_security_group_id = azurerm_network_security_group.control_plane_nsg.id
}

# -------------------------
# NSG Association for Worker Nodes
# -------------------------
resource "azurerm_network_interface_security_group_association" "worker_assoc" {
  for_each = {
    worker1 = azurerm_network_interface.main["worker1"].id
    worker2 = azurerm_network_interface.main["worker2"].id
  }

  network_interface_id      = each.value
  network_security_group_id = azurerm_network_security_group.worker_nsg.id
}

# -------------------------
# Linux Virtual Machines
# -------------------------
resource "azurerm_linux_virtual_machine" "main" {
  for_each = var.network_interface_name

  name                = each.key
  resource_group_name = azurerm_resource_group.kubeadm_rg.name
  location            = azurerm_resource_group.kubeadm_rg.location
  size                = "Standard_DS1_v2"
  admin_username      = "adminuser"

  network_interface_ids = [
    azurerm_network_interface.main[each.key].id
  ]



  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}
