output "admin_password" {
  sensitive = true
  value     = azurerm_mysql_flexible_server.default.administrator_password
}