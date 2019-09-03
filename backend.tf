#Remote state azure storage account (blob)

terraform {
  backend "azurerm" {
    storage_account_name = "rltfbackend"
    container_name       = "tfstate"
    access_key           = "yourStorageKeyHere"
    key                  = "terraform.tfstate"
  }
}
