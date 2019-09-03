/*

 +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
 |w|w|w|.|r|l|e|v|c|h|e|n|k|o|.|c|o|m|
 +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+ 

 :: Terraform remote state configuration (Blob)
    
*/

terraform {
  backend "azurerm" {
    storage_account_name = "rltfbackend"
    container_name       = "tfstate"
    access_key           = "yourStorageKeyHere"
    key                  = "terraform.tfstate"
  }
}
