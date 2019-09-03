/*

 +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
 |w|w|w|.|r|l|e|v|c|h|e|n|k|o|.|c|o|m|
 +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+ 

 :: Azure provider authentication
    
*/

variable "client_secret" {} #Variable to store SP's password

provider "azurerm" {
  version         = "=1.24.0"                # (optional) provider's version
  subscription_id = "997f9727-xxx-xxxx"
  client_id       = "d53-xxx-xxx-xxxx"
  client_secret   = "${var.client_secret}"
  tenant_id       = "d373-xxxx-xxx-xxx-xxxx"
}
