# 1. Resource Group
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    Environment = "DevOps Course"
    Chapter     = "11-terraform"
  }
}

# 2. Virtual Network & Subnet
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-${var.vm_name}"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  tags = {
    Environment = "DevOps Course"
    Chapter     = "11-terraform"
  }
}

resource "azurerm_subnet" "subnet" {
  name                 = "subnet-internal"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# 3. Public IP
resource "azurerm_public_ip" "pip" {
  name                = "pip-${var.vm_name}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    Environment = "DevOps Course"
    Role        = var.vm_name
  }
}

# 4. Network Security Group (NSG)
resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-${var.vm_name}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "Allow-SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-App-HTTP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8000"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    Environment = "DevOps Course"
    Role        = var.vm_name
  }
}

# 5. Network Interface (NIC) & NSG Association
resource "azurerm_network_interface" "nic" {
  name                = "nic-${var.vm_name}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig-primary"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip.id
  }

  tags = {
    Environment = "DevOps Course"
    Role        = var.vm_name
  }
}

resource "azurerm_network_interface_security_group_association" "nsg_assoc" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# 6. Automatic SSH Key Pair (generated if ssh_public_key is not supplied)
resource "tls_private_key" "ssh_key" {
  count     = var.ssh_public_key == "" ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "private_key" {
  count           = var.ssh_public_key == "" ? 1 : 0
  content         = tls_private_key.ssh_key[0].private_key_pem
  filename        = "${path.module}/${var.vm_name}_key.pem"
  file_permission = "0600"
}

# 7. Ubuntu Linux Virtual Machine (server2)
resource "azurerm_linux_virtual_machine" "vm" {
  name                = var.vm_name
  computer_name       = var.vm_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = var.vm_size
  admin_username      = var.admin_username
  network_interface_ids = [
    azurerm_network_interface.nic.id,
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key != "" ? var.ssh_public_key : tls_private_key.ssh_key[0].public_key_openssh
  }

  os_disk {
    name                 = "osdisk-${var.vm_name}"
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  tags = {
    Environment = "DevOps Course"
    Role        = var.vm_name
    Chapter     = "11-terraform"
  }
}

