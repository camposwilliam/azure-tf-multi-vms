provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-vmliux"
  location = "brazilsouth"
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vmliux-vnet"
  address_space       = ["10.0.0.0/16", "192.168.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

}

resource "azurerm_subnet" "subnet" {
  name                 = "vmliux-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_public_ip" "publicip" {
  count = var.node_count
  name                    = "vmliux-ippublic${count.index}"
  location                = azurerm_resource_group.rg.location
  resource_group_name     = azurerm_resource_group.rg.name
  allocation_method       = "Dynamic"
  idle_timeout_in_minutes = 30
}

resource "azurerm_network_interface" "nic" {
  count = var.node_count
  name                = "vmliux-nic${count.index}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipexterno-config"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = element(azurerm_public_ip.publicip.*.id, count.index)
  }
}

resource "azurerm_network_security_group" "nsg" {
  name                = "vmliux-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

}


variable "regras_entrada" {
  type = map(any)
  default = {
    101 = 80
    102 = 443
    103 = 3389
    104 = 22
  }
}


resource "azurerm_network_security_rule" "regras_entrada_liberada" {
  for_each                    = var.regras_entrada
  resource_group_name         = azurerm_resource_group.rg.name
  name                        = "porta_entrada_${each.value}"
  priority                    = each.key
  direction                   = "Inbound"
  access                      = "Allow"
  source_port_range           = "*"
  protocol                    = "Tcp"
  destination_port_range      = each.value
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  network_security_group_name = azurerm_network_security_group.nsg.name

}

resource "azurerm_subnet_network_security_group_association" "nsgassociacao" {
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}


resource "azurerm_linux_virtual_machine" "vmlinux" {
  count = var.node_count
  name                = "vmlinuxserver${count.index}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  size                  = "Standard_B1ls"
  admin_username        = "adminuser"
  admin_password        = "Marley@Odin@2021"
  network_interface_ids = [element(azurerm_network_interface.nic.*.id, count.index)]

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"

  }
}
