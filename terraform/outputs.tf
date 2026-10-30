output "resource_group_name" {
  description = "The Resource Group name"
  value       = azurerm_resource_group.rg.name
}

output "vm_name" {
  description = "Virtual Machine hostname"
  value       = azurerm_linux_virtual_machine.vm.name
}

output "public_ip" {
  description = "Public IP address of server2"
  value       = azurerm_public_ip.pip.ip_address
}

output "ssh_private_key_file" {
  description = "Local path to the SSH private key"
  value       = var.ssh_public_key == "" ? local_file.private_key[0].filename : "server_key.pem"
}

output "ssh_login_command" {
  description = "Command to SSH into server2"
  value = var.ssh_public_key == "" ? (
    "ssh -i terraform/${var.vm_name}_key.pem ${var.admin_username}@${azurerm_public_ip.pip.ip_address}"
  ) : (
    "ssh -i server_key.pem ${var.admin_username}@${azurerm_public_ip.pip.ip_address}"
  )
}

