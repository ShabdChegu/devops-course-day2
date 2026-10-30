variable "location" {
  type        = string
  description = "Azure region where resources will be created"
  default     = "centralindia"
}

variable "resource_group_name" {
  type        = string
  description = "Name of the Azure Resource Group"
  default     = "rg-devops-course-centralindia"
}

variable "vm_name" {
  type        = string
  description = "Hostname and resource name for the Azure VM"
  default     = "server2"
}

variable "vm_size" {
  type        = string
  description = "Azure VM size (2 vCPU, 8GB RAM)"
  default     = "Standard_D2s_v3"
}

variable "admin_username" {
  type        = string
  description = "Administrator username for SSH access to the VM"
  default     = "azureuser"
}

variable "ssh_public_key" {
  type        = string
  description = "Optional external SSH public key string. If left blank, Terraform automatically generates a 4096-bit RSA key."
  default     = ""
}

