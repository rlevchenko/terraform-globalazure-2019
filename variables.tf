/*
 +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
 |w|w|w|.|r|l|e|v|c|h|e|n|k|o|.|c|o|m|
 +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+ 

 :: Configuration variables
    
*/

#Location
variable "loc" {
  type        = "string"
  default     = "West Europe"
  description = "Default location for VMs"
}

#Demostor
variable "addstor" {
  default     = false
  description = "Should we deploy additional storage account?"
}

#Tags
variable "tags" {
  type = "map"

  default = {
    app  = "web"
    dept = "IT"
  }

  description = "Tags for all resources"
}

#Azure DevOps
variable "pattoken" {}

variable "devops" {
  default = true
}

#Counts
variable "pcs" {
  default     = 2
  description = "How many VMs should be deployed?"
}

#NSGs parameters
variable "ports" {
  type        = "list"
  default     = ["3389", "80", "443"]
  description = "which ports should be allowed by NSG?"
}

#Image settings
variable "custom_image_resource_group_name" {
  default     = "Bootcamp"
  description = "The name of the Resource Group in which the Custom Image exists."
}

variable "custom_image_name" {
  default     = "ws2019-iis"
  description = "The name of the Custom Image to provision this Virtual Machine from."
}
