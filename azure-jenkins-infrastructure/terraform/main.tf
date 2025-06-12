# Configuración de Terraform
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
  required_version = ">= 1.0"
}

# Configuración del proveedor Azure
provider "azurerm" {
  features {}
  
  # Deshabilitar registro automático de Resource Providers
  # para evitar conflictos en suscripciones de estudiante
  resource_provider_registrations = "none"
}

# Generar clave SSH automáticamente
resource "tls_private_key" "jenkins_ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Resource Group
resource "azurerm_resource_group" "jenkins" {
  name     = "jenkins-rg"
  location = "East US"
  
  tags = {
    Environment = "Development"
    Project     = "Jenkins-Azure"
    ManagedBy   = "Terraform"
  }
}

# Virtual Network
resource "azurerm_virtual_network" "jenkins" {
  name                = "jenkins-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.jenkins.location
  resource_group_name = azurerm_resource_group.jenkins.name

  tags = azurerm_resource_group.jenkins.tags
}

# Subnet
resource "azurerm_subnet" "internal" {
  name                 = "default"
  resource_group_name  = azurerm_resource_group.jenkins.name
  virtual_network_name = azurerm_virtual_network.jenkins.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Network Security Group
resource "azurerm_network_security_group" "jenkins" {
  name                = "jenkins-nsg"
  location            = azurerm_resource_group.jenkins.location
  resource_group_name = azurerm_resource_group.jenkins.name

  # SSH
  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Jenkins Web UI
  security_rule {
    name                       = "Jenkins"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8080"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Jenkins Agent Communication
  security_rule {
    name                       = "Jenkins-Agent"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "50000"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = azurerm_resource_group.jenkins.tags
}

# Public IP para Master (solo el master necesita IP pública)
resource "azurerm_public_ip" "master" {
  name                = "jenkins-master-pip"
  location            = azurerm_resource_group.jenkins.location
  resource_group_name = azurerm_resource_group.jenkins.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = azurerm_resource_group.jenkins.tags
}

# Network Interface para Master
resource "azurerm_network_interface" "master" {
  name                = "jenkins-master-nic"
  location            = azurerm_resource_group.jenkins.location
  resource_group_name = azurerm_resource_group.jenkins.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.1.10"
    public_ip_address_id          = azurerm_public_ip.master.id
  }

  tags = azurerm_resource_group.jenkins.tags
}

# Network Interface para Slave
resource "azurerm_network_interface" "slave" {
  name                = "jenkins-slave-nic"
  location            = azurerm_resource_group.jenkins.location
  resource_group_name = azurerm_resource_group.jenkins.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.1.11"
  }

  tags = azurerm_resource_group.jenkins.tags
}

# Asociar NSG a subnet
resource "azurerm_subnet_network_security_group_association" "jenkins" {
  subnet_id                 = azurerm_subnet.internal.id
  network_security_group_id = azurerm_network_security_group.jenkins.id
}

# VM Jenkins Master
resource "azurerm_linux_virtual_machine" "master" {
  name                = "jenkins-master"
  resource_group_name = azurerm_resource_group.jenkins.name
  location            = azurerm_resource_group.jenkins.location
  size                = "Standard_B2s"
  admin_username      = "azureuser"

  # Deshabilitar autenticación por password, usar solo SSH keys
  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.master.id,
  ]

  admin_ssh_key {
    username   = "azureuser"
    public_key = tls_private_key.jenkins_ssh.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  tags = azurerm_resource_group.jenkins.tags
}

# VM Jenkins Slave
resource "azurerm_linux_virtual_machine" "slave" {
  name                = "jenkins-slave"
  resource_group_name = azurerm_resource_group.jenkins.name
  location            = azurerm_resource_group.jenkins.location
  size                = "Standard_B2s"
  admin_username      = "azureuser"

  # Deshabilitar autenticación por password, usar solo SSH keys
  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.slave.id,
  ]

  admin_ssh_key {
    username   = "azureuser"
    public_key = tls_private_key.jenkins_ssh.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  tags = azurerm_resource_group.jenkins.tags
} 