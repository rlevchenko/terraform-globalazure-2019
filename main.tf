/*

 +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
 |w|w|w|.|r|l|e|v|c|h|e|n|k|o|.|c|o|m|
 +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+ 

 :: Terraform main confiration file
 :: Deploys VMs with Availability Set, Load Balancer, NSGs and adds VMs to Azure DevOps Deployment Group (CD)
    
*/

#Environments sample
locals {
  environment = "${terraform.workspace}"

  counts = {
    "default" = 2
    "dev"     = 1
  }

  vmtypes = {
    "default" = "Standard_D1_v2"
    "dev"     = "Standard_A1_v2"
  }

  count  = "${lookup(local.counts, local.environment)}"
  vmsize = "${lookup(local.vmtypes, local.environment)}"
}

#Container for our resources

resource "azurerm_resource_group" "labrg" {
  name     = "rllabs"
  location = "${var.loc}"
  tags     = "${var.tags}"
}

#Random string for resources naming
resource "random_string" "labrndstr" {
  length  = 8
  lower   = true
  number  = true
  upper   = false
  special = false
}

#Password generator
resource "random_string" "pwd" {
  length           = 12
  lower            = true
  number           = true
  upper            = true
  special          = true
  override_special = "!#"
  min_numeric      = 3
  min_lower        = 3
  min_upper        = 3
  min_special      = 2
}

#Get secret from Azure Vault (sample)
/*

data "azurerm_key_vault_secret" "secret" {
name = "vmadmin"
vault_uri = "https://yourKeyVault.vault.azure.net/"
}

resource vm ..
..
admin_password = "${data.azurerm_key_vault_secret.secret.value}"
..

*/

resource "azurerm_storage_account" "demostor" {
  name                     = "demo${random_string.labrndstr.result}"
  count                    = "${local.count}"
  resource_group_name      = "${azurerm_resource_group.labrg.name}"
  location                 = "${azurerm_resource_group.labrg.location}"
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = {
    Environment = "${terraform.workspace}"
  }
}

#Let's create AS for our VMs (inline)

/*
resource "azurerm_availability_set" "vmha" {
  name                = "vmha-${random_string.labrndstr.result}"
  location            = "${azurerm_resource_group.labrg.location}"
  resource_group_name = "${azurerm_resource_group.labrg.name}"
  tags                = "${var.tags}"
  managed             = true
} */

#let's create AS for our VMs (modules)

module "avset" {
  source     = "./modules/avset"
  count      = "${local.count}"
  location   = "${azurerm_resource_group.labrg.location}"
  rg_name    = "${azurerm_resource_group.labrg.name}"
  tags       = "${azurerm_resource_group.labrg.tags}"
  avset_name = "${random_string.labrndstr.result}"
}

#Preparing network resources
resource "azurerm_public_ip" "publicIp" {
  name                = "lbPublicIp"
  location            = "${azurerm_resource_group.labrg.location}"
  resource_group_name = "${azurerm_resource_group.labrg.name}"
  allocation_method   = "Static"
  tags                = "${azurerm_resource_group.labrg.tags}"
}

resource "azurerm_virtual_network" "vNetwork" {
  name                = "core"
  address_space       = ["10.0.0.0/16"]
  dns_servers         = ["1.1.1.1", "1.0.0.1"]
  resource_group_name = "${azurerm_resource_group.labrg.name}"
  location            = "${azurerm_resource_group.labrg.location}"
  tags                = "${azurerm_resource_group.labrg.tags}"

  subnet {
    name           = "backendSubnet"
    address_prefix = "10.0.0.0/24"
  }
}

#Load Balancer resource
resource "azurerm_lb" "loadBalancer" {
  name                = "vmLoadBalancer"
  location            = "${azurerm_resource_group.labrg.location}"
  resource_group_name = "${azurerm_resource_group.labrg.name}"
  sku                 = "Basic"

  frontend_ip_configuration {
    name                 = "lbExtIP"
    public_ip_address_id = "${azurerm_public_ip.publicIp.id}"
  }
}

#LB BackEnd Pool
resource "azurerm_lb_backend_address_pool" "backendPool" {
  name                = "backendVMs"
  resource_group_name = "${azurerm_resource_group.labrg.name}"
  loadbalancer_id     = "${azurerm_lb.loadBalancer.id}"
}

#Health probe (just checks RDP port on VMs)
resource "azurerm_lb_probe" "backendHealth" {
  resource_group_name = "${azurerm_resource_group.labrg.name}"
  loadbalancer_id     = "${azurerm_lb.loadBalancer.id}"
  name                = "rdp-running-probe"
  port                = 80
}

#NAT Rule for RDP
resource "azurerm_lb_nat_rule" "rdp-nat" {
  resource_group_name            = "${azurerm_resource_group.labrg.name}"
  loadbalancer_id                = "${azurerm_lb.loadBalancer.id}"
  name                           = "RDPAccess"
  protocol                       = "Tcp"
  frontend_port                  = 3389
  backend_port                   = 3389
  frontend_ip_configuration_name = "lbExtIP"
}

#LB Rule for HTTPS
resource "azurerm_lb_rule" "https" {
  resource_group_name            = "${azurerm_resource_group.labrg.name}"
  loadbalancer_id                = "${azurerm_lb.loadBalancer.id}"
  backend_address_pool_id        = "${azurerm_lb_backend_address_pool.backendPool.id}"
  name                           = "HTTPS"
  protocol                       = "Tcp"
  frontend_port                  = 443
  backend_port                   = 443
  frontend_ip_configuration_name = "lbExtIP"
}

#LB Rule for HTTP
resource "azurerm_lb_rule" "http" {
  resource_group_name            = "${azurerm_resource_group.labrg.name}"
  loadbalancer_id                = "${azurerm_lb.loadBalancer.id}"
  backend_address_pool_id        = "${azurerm_lb_backend_address_pool.backendPool.id}"
  name                           = "HTTP"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "lbExtIP"
}

#Network building + ASG/NSGs

resource "azurerm_network_interface" "vNIC" {
  count               = "${var.pcs}"
  name                = "vNic-${count.index + 1}"
  location            = "${azurerm_resource_group.labrg.location}"
  resource_group_name = "${azurerm_resource_group.labrg.name}"

  ip_configuration {
    name                          = "vm-${count.index + 1}-ipconfig"
    subnet_id                     = "${lookup(azurerm_virtual_network.vNetwork.subnet[0], "id")}"
    private_ip_address_allocation = "Dynamic"
  }
}

#Mapping network interface to NAT rule
resource "azurerm_network_interface_nat_rule_association" "rdp01-to-nat" {
  network_interface_id  = "${element(azurerm_network_interface.vNIC.*.id, count.index)}"
  ip_configuration_name = "vm-${count.index + 1}-ipconfig"
  nat_rule_id           = "${azurerm_lb_nat_rule.rdp-nat.id}"
}

#Mapping created vNIC to LB backend pool
resource "azurerm_network_interface_backend_address_pool_association" "lbMapping" {
  count                   = "${var.pcs}"
  network_interface_id    = "${element(azurerm_network_interface.vNIC.*.id, count.index)}"
  ip_configuration_name   = "vm-${count.index + 1}-ipconfig"
  backend_address_pool_id = "${azurerm_lb_backend_address_pool.backendPool.id}"
}

#Application Security Group
resource "azurerm_application_security_group" "appgp" {
  name                = "appgp-${random_string.labrndstr.result}"
  location            = "${azurerm_resource_group.labrg.location}"
  resource_group_name = "${azurerm_resource_group.labrg.name}"
  tags                = "${azurerm_resource_group.labrg.tags}"
}

resource "azurerm_network_interface_application_security_group_association" "asgmapping" {
  count                         = "${var.pcs}"
  network_interface_id          = "${element(azurerm_network_interface.vNIC.*.id, count.index)}"
  ip_configuration_name         = "vm-${count.index + 1}-ipconfig"
  application_security_group_id = "${azurerm_application_security_group.appgp.id}"
}

#NSG and rules
resource "azurerm_network_security_group" "NSG" {
  name                = "vmNSG"
  resource_group_name = "${azurerm_resource_group.labrg.name}"
  location            = "${azurerm_resource_group.labrg.location}"
  tags                = "${azurerm_resource_group.labrg.tags}"
}

resource "azurerm_network_security_rule" "nsgRDP" {
  count                                      = 3
  name                                       = "rule-${count.index + 1}"
  resource_group_name                        = "${azurerm_resource_group.labrg.name}"
  network_security_group_name                = "${azurerm_network_security_group.NSG.name}"
  destination_application_security_group_ids = ["${azurerm_application_security_group.appgp.id}"]

  priority               = "101${count.index + 1}"
  access                 = "Allow"
  direction              = "Inbound"
  protocol               = "Tcp"
  destination_port_range = "${element(var.ports,count.index)}"
  source_port_range      = "*"
  source_address_prefix  = "*"
}

#Cooking VMs with managed disks :)

#Get custom image that will be used by VMs
data "azurerm_image" "custom" {
  name                = "${var.custom_image_name}"
  resource_group_name = "${var.custom_image_resource_group_name}"
}

resource "azurerm_virtual_machine" "vMachines" {
  count    = "${var.pcs}"
  name     = "vm-${random_string.labrndstr.result}-${count.index + 1}"
  location = "${azurerm_resource_group.labrg.location}"

  # availability_set_id          = "${azurerm_availability_set.vmha.id}"
  availability_set_id          = "${module.avset.id[0]}"
  resource_group_name          = "${azurerm_resource_group.labrg.name}"
  vm_size                      = "${local.vmsize}"
  network_interface_ids        = ["${azurerm_network_interface.vNIC.*.id[count.index]}"]
  primary_network_interface_id = "${element(azurerm_network_interface.vNIC.*.id, count.index)}"

  storage_image_reference {
    id = "${data.azurerm_image.custom.id}"

    # From MarketPlace image 
    # publisher = "MicrosoftWindowsServer"
    # offer     = "WindowsServer"
    # sku       = "2019-Datacenter"
    # version   = "Latest"  
  }

  storage_os_disk {
    name              = "osDisk-${count.index}"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "labpc-${count.index}"
    admin_username = "rladmin"
    admin_password = "${random_string.pwd.result}"
  }

  os_profile_windows_config {
    provision_vm_agent = true
    timezone           = "Russian Standard Time"
  }

  tags = "${azurerm_resource_group.labrg.tags}"
}

#Azure DevOps Extension
resource "azurerm_virtual_machine_extension" "vsts" {
  count                = "${var.devops ? var.pcs:0}"
  name                 = "DevOpsAddIn"
  location             = "${azurerm_resource_group.labrg.location}"
  resource_group_name  = "${azurerm_resource_group.labrg.name}"
  virtual_machine_name = "vm-${random_string.labrndstr.result}-${count.index + 1}"
  publisher            = "Microsoft.VisualStudio.Services"
  type                 = "TeamServicesAgent"
  type_handler_version = "1.23"

  settings = <<SETTINGS
    {
        "VSTSAccountName": "https://rlevchenko.visualstudio.com",
        "TeamProject": "WebApp",
        "DeploymentGroup": "WebApp-CD",
        "Tags":"dev"
    }SETTINGS

  protected_settings = <<PROTECTED_SETTINGS
        {
       "PATToken": "${var.pattoken}"
        }PROTECTED_SETTINGS

  tags       = "${azurerm_resource_group.labrg.tags}"
  depends_on = ["azurerm_virtual_machine.vMachines"]
}

#VM Admin's password and etc. Write it down! (please note: it's not a great idea to output pwd in case of prod)
output "pwd" {
  value       = "${random_string.pwd.result}"
  description = "VM's admin password!!"
}

output "publicIP" {
  value       = "${azurerm_public_ip.publicIp.ip_address}"
  description = "Use this IP for RDP connection"
}
