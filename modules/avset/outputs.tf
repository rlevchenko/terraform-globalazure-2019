output "id" {
  value = "${azurerm_availability_set.avail_set.*.id}"
}
