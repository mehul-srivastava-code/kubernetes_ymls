variable "azurerm_resource_group_name" {
  type        = string
  description = "The name of the resource group"
  default     = "kubeadm-rg"
}

variable "location" {
  type        = string
  description = "Azure region"
  default     = "southeastasia"
}

variable "vnet_name" {
  type        = string
  description = "Virtual Network name"
  default     = "kubeadm-vnet"
}

variable "subnet" {
  description = "Subnet CIDR blocks"
  type        = map(string)

  default = {
    control-plane = "10.0.2.0/24"
    worker-1      = "10.0.3.0/24"
    worker-2      = "10.0.4.0/24"
  }
}

variable "network_interface_name" {
  description = "VMs and their corresponding subnet keys"
  type = map(object({
    subnet_key = string
  }))

  default = {
    master  = { subnet_key = "control-plane" }
    worker1 = { subnet_key = "worker-1" }
    worker2 = { subnet_key = "worker-2" }
  }
}


