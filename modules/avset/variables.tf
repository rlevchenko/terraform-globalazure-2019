/*

 +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
 |w|w|w|.|r|l|e|v|c|h|e|n|k|o|.|c|o|m|
 +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+ 

 :: Terraform module variables
    
*/
variable "location" {
  description = "Availability Set location"
}

variable "avset_name" {
  description = "Name"
}

variable "rg_name" {
  description = "Resource Group Name"
}

variable "tags" {
  description = "Resource Group Environment Tag"
  type        = "map"
}

variable "count" {
  description = "Number of Availability Sets to create"
}
