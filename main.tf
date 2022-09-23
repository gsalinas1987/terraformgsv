provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "msd-rg" {
  name     = "msdrggsv"
  location = var.location
}

resource "azurerm_virtual_network" "msd-vnet" {
  name                = "${var.environment}-vnet-gsv"
  address_space       = ["10.0.0.0/16"]
  location            = var.location
  resource_group_name = azurerm_resource_group.msd-rg.name
}

resource "azurerm_subnet" "msd-snet" {
  name                 = "${var.environment}-snet-gsv"
  resource_group_name  = azurerm_resource_group.msd-rg.name
  virtual_network_name = azurerm_virtual_network.msd-vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_subnet" "msd-lb-snet" {
  name                 = "${var.environment}-lb-snet-gsv"
  resource_group_name  = azurerm_resource_group.msd-rg.name
  virtual_network_name = azurerm_virtual_network.msd-vnet.name
  address_prefixes     = ["10.0.3.0/24"]
}

resource "azurerm_public_ip" "msd-pip" {
  name                = "${var.environment}-pip-gsv"
  location            = var.location
  resource_group_name = azurerm_resource_group.msd-rg.name
  allocation_method   = "Static"
  domain_name_label   = azurerm_resource_group.msd-rg.name

  tags = {
    environment = var.environment
  }
}

resource "azurerm_availability_set" "msd-aset" {
  name                = "${var.environment}-aset-gsv"
  location            = var.location
  resource_group_name = azurerm_resource_group.msd-rg.name
  platform_fault_domain_count = 2
  platform_update_domain_count = 3

  tags = {
    environment = var.environment
  }
}

resource "azurerm_network_security_group" "msd-nsg" {
  name                = "${var.environment}-nsg-gsv"
  location            = var.location
  resource_group_name = azurerm_resource_group.msd-rg.name

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
  security_rule {
    name                       = "HTTP"
    priority                   = 301
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "msd-vm-nic1" {
  name                = "${var.environment}-nic-gsv1"
  location            = var.location
  resource_group_name = azurerm_resource_group.msd-rg.name

  ip_configuration {
    name                          = "${var.environment}-nic-config"
    subnet_id                     = azurerm_subnet.msd-snet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface" "msd-vm-nic2" {
  name                = "${var.environment}-nic-gsv2"
  location            = var.location
  resource_group_name = azurerm_resource_group.msd-rg.name

  ip_configuration {
    name                          = "${var.environment}-nic-config"
    subnet_id                     = azurerm_subnet.msd-snet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface_security_group_association" "msd-nsg-nic1" {
  network_interface_id      = azurerm_network_interface.msd-vm-nic1.id
  network_security_group_id = azurerm_network_security_group.msd-nsg.id
}

resource "azurerm_network_interface_security_group_association" "msd-nsg-nic2" {
  network_interface_id      = azurerm_network_interface.msd-vm-nic2.id
  network_security_group_id = azurerm_network_security_group.msd-nsg.id
}

resource "azurerm_linux_virtual_machine" "msd-vm-1" {
  name                = "${var.environment}-vm1-gsv"
  resource_group_name = azurerm_resource_group.msd-rg.name
  location            = var.location
  size                = var.vmsize
  admin_username      = "azureuser"
  network_interface_ids = [
    azurerm_network_interface.msd-vm-nic1.id,
  ]
  availability_set_id = azurerm_availability_set.msd-aset.id

  admin_ssh_key {
    username   = "azureuser"
    public_key = file("/mnt/c/Users/gesalinas/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18_04-lts-gen2"
    version   = "latest"
  }
}

resource "azurerm_linux_virtual_machine" "msd-vm-2" {
  name                = "${var.environment}-vm2-gsv"
  resource_group_name = azurerm_resource_group.msd-rg.name
  location            = var.location
  size                = var.vmsize
  admin_username      = "azureuser"
  network_interface_ids = [
    azurerm_network_interface.msd-vm-nic2.id,
  ]
  availability_set_id = azurerm_availability_set.msd-aset.id

  admin_ssh_key {
    username   = "azureuser"
    public_key = file("/mnt/c/Users/gesalinas/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18_04-lts-gen2"
    version   = "latest"
  }
}

resource "azurerm_lb" "msd-lb-gsv" {
  name                = "${var.environment}-lb-gsv"
  location            = var.location
  resource_group_name = azurerm_resource_group.msd-rg.name

  frontend_ip_configuration {
    name                 = "${var.environment}-fe-pip"
    public_ip_address_id = azurerm_public_ip.msd-pip.id
  }
}

resource "azurerm_lb_backend_address_pool" "bpepool" {
  loadbalancer_id     = azurerm_lb.msd-lb-gsv.id
  name                = "BackEndAddressPool"
}

resource "azurerm_lb_nat_pool" "lbnatpool" {
  resource_group_name            = azurerm_resource_group.msd-rg.name
  name                           = "ssh"
  loadbalancer_id                = azurerm_lb.msd-lb-gsv.id
  protocol                       = "Tcp"
  frontend_port_start            = 50000
  frontend_port_end              = 50119
  backend_port                   = 22
  frontend_ip_configuration_name = "${var.environment}-fe-pip"
}

resource "azurerm_lb_probe" "health-probe" {
  loadbalancer_id     = azurerm_lb.msd-lb-gsv.id
  name                = "http-probe"
  protocol            = "Http"
  request_path        = "/"
  port                = 80
}

resource "azurerm_network_interface_backend_address_pool_association" "msd-assoc-lb-1" {
  network_interface_id    = azurerm_network_interface.msd-vm-nic1.id
  ip_configuration_name   = azurerm_network_interface.msd-vm-nic1.ip_configuration[0].name
  backend_address_pool_id = azurerm_lb_backend_address_pool.bpepool.id
  depends_on = [
    azurerm_network_interface.msd-vm-nic1
  ]
}

resource "azurerm_network_interface_backend_address_pool_association" "msd-assoc-lb-2" {
  network_interface_id    = azurerm_network_interface.msd-vm-nic2.id
  ip_configuration_name   = azurerm_network_interface.msd-vm-nic2.ip_configuration[0].name
  backend_address_pool_id = azurerm_lb_backend_address_pool.bpepool.id
  depends_on = [
    azurerm_network_interface.msd-vm-nic2
  ]
}
