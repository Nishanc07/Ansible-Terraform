# Get your public IP for NSG rules
data "http" "my_ip" {
  url = "https://api.ipify.org"
}

# Subnet CIDR
locals {
  alpha_address_space = cidrsubnet(var.base_address_space, 2, 0)
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = "rg-${var.application_name}-${var.environment_name}"
  location = var.primary_location
}

# Virtual Network
resource "azurerm_virtual_network" "main" {
  name                = "vnet-${var.application_name}-${var.environment_name}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = [var.base_address_space]
}

# Subnet
resource "azurerm_subnet" "alpha" {
  name                 = "snet-alpha"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [local.alpha_address_space]
}

# NSG allowing SSH & SonarQube
resource "azurerm_network_security_group" "remote_access" {
  name                = "nsg-${var.application_name}-${var.environment_name}-remote-access"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = chomp(data.http.my_ip.response_body)
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "SonarQube"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "9000"
    source_address_prefix      = chomp(data.http.my_ip.response_body)
    destination_address_prefix = "*"
  }
}

# Public IPs
resource "azurerm_public_ip" "vm" {
  count               = var.number_of_instances
  name                = "pip-${var.application_name}-${var.environment_name}-vm${count.index + 1}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
}

# NICs
resource "azurerm_network_interface" "vm" {
  count               = var.number_of_instances
  name                = "nic-${var.application_name}-${var.environment_name}-vm${count.index + 1}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.alpha.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm[count.index].id
  }
}

# Attach NIC to NSG
resource "azurerm_network_interface_security_group_association" "nic_nsg" {
  count                     = var.number_of_instances
  network_interface_id      = azurerm_network_interface.vm[count.index].id
  network_security_group_id = azurerm_network_security_group.remote_access.id
}

# Generate SSH key
resource "tls_private_key" "vm" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Save private key locally
resource "local_file" "private_key" {
  content         = tls_private_key.vm.private_key_pem
  filename        = pathexpand("~/.ssh/azure_vm_key")
  file_permission = "0600"
}

# Save public key locally
resource "local_file" "public_key" {
  content         = tls_private_key.vm.public_key_openssh
  filename        = pathexpand("~/.ssh/azure_vm_key.pub")
  file_permission = "0644"
}

# Linux VMs
resource "azurerm_linux_virtual_machine" "vm" {
  count                 = var.number_of_instances
  name                  = "vm-${var.application_name}-${var.environment_name}-${count.index + 1}"
  location              = azurerm_resource_group.main.location
  resource_group_name   = azurerm_resource_group.main.name
  size                  = "Standard_B2s"
  admin_username        = "adminuser"
  network_interface_ids = [azurerm_network_interface.vm[count.index].id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  admin_ssh_key {
    username   = "adminuser"
    public_key = tls_private_key.vm.public_key_openssh
  }

  identity {
    type = "SystemAssigned"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}

# Upload same public key via SSH (optional — used in your AWS setup)
resource "null_resource" "configure_ssh" {
  count = var.number_of_instances

  connection {
    type        = "ssh"
    host        = azurerm_public_ip.vm[count.index].ip_address
    user        = "adminuser"
    private_key = tls_private_key.vm.private_key_pem
    timeout     = "2m"
  }

  provisioner "file" {
    source      = local_file.public_key.filename
    destination = "/home/adminuser/extra_id.pub"
  }

  provisioner "remote-exec" {
    inline = [
      "mkdir -p ~/.ssh",
      "cat ~/extra_id.pub >> ~/.ssh/authorized_keys",
      "chmod 700 ~/.ssh",
      "chmod 600 ~/.ssh/authorized_keys",
      "rm ~/extra_id.pub"
    ]
  }

  depends_on = [azurerm_linux_virtual_machine.vm]
}

# Disable strict host key checking
resource "null_resource" "disable_strict_host_key_checking" {
  count = var.number_of_instances

  connection {
    type        = "ssh"
    host        = azurerm_public_ip.vm[count.index].ip_address
    user        = "adminuser"
    private_key = tls_private_key.vm.private_key_pem
    timeout     = "2m"
  }

  provisioner "remote-exec" {
    inline = [
      "mkdir -p ~/.ssh",
      "echo 'Host *' >> ~/.ssh/config",
      "echo '  StrictHostKeyChecking no' >> ~/.ssh/config",
      "echo '  UserKnownHostsFile=/dev/null' >> ~/.ssh/config",
      "echo '  LogLevel ERROR' >> ~/.ssh/config"
    ]
  }

  depends_on = [azurerm_linux_virtual_machine.vm]
}

# Output public IPs
output "vm_public_ips" {
  value = {
    for idx, pip in azurerm_public_ip.vm :
    "vm-${idx + 1}" => pip.ip_address
  }
}
