# Create the resource group
resource "azurerm_resource_group" "rg" {
  name     = "surreylm-app-rg"
  location = "uksouth"
}

# Generate random value for the name
resource "random_string" "name" {
  length  = 8
  lower   = true
  numeric = false
  special = false
  upper   = false
}

# Generate random value for the login password
resource "random_password" "password" {
  length           = 8
  lower            = true
  min_lower        = 1
  min_numeric      = 1
  min_special      = 1
  min_upper        = 1
  numeric          = true
  override_special = "_"
  special          = true
  upper            = true
}

# Manages the Virtual Network
resource "azurerm_virtual_network" "default" {
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  name                = "vnet-surreylm"
  resource_group_name = azurerm_resource_group.rg.name
}

# Manages the Subnet
resource "azurerm_subnet" "default" {
  address_prefixes     = ["10.0.2.0/24"]
  name                 = "subnet-surreylm-db"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.default.name
  service_endpoints    = ["Microsoft.Storage"]

  delegation {
    name = "fs"

    service_delegation {
      name = "Microsoft.DBforMySQL/flexibleServers"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}

resource "azurerm_subnet" "sn1" {
  name                 = "surreylm-prod-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.default.name
  address_prefixes     = ["10.0.1.0/24"]

  delegation {
    name = "example-delegation"

    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

# Enables you to manage Private DNS zones within Azure DNS
resource "azurerm_private_dns_zone" "default" {
  name                = "surreylm.mysql.database.azure.com"
  resource_group_name = azurerm_resource_group.rg.name
}

# Enables you to manage Private DNS zone Virtual Network Links
resource "azurerm_private_dns_zone_virtual_network_link" "default" {
  name                  = "mysqlfsVnetZoneSurreyLM.com"
  private_dns_zone_name = azurerm_private_dns_zone.default.name
  resource_group_name   = azurerm_resource_group.rg.name
  virtual_network_id    = azurerm_virtual_network.default.id

  depends_on = [azurerm_subnet.default]
}

# Manages the MySQL Flexible Server
resource "azurerm_mysql_flexible_server" "default" {
  location                     = azurerm_resource_group.rg.location
  name                         = "surreylm-db"
  resource_group_name          = azurerm_resource_group.rg.name
  administrator_login          = "surreylm_admin"
  administrator_password       = random_password.password.result
  backup_retention_days        = 7
  delegated_subnet_id          = azurerm_subnet.default.id
  geo_redundant_backup_enabled = false
  private_dns_zone_id          = azurerm_private_dns_zone.default.id
  sku_name                     = "B_Standard_B1s"
  version                      = "8.0.21"
  storage {
    iops    = 360
    size_gb = 20
  }

  depends_on = [azurerm_private_dns_zone_virtual_network_link.default]
}

# Create the Linux App Service Plan
resource "azurerm_service_plan" "appserviceplan" {
  name                = "surreylm-app-plan"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  os_type             = "Linux"
  sku_name            = "B1"
}

# Create prod app
resource "azurerm_linux_web_app" "webapp" {
  name                  = "surreylm-prod-app"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  service_plan_id       = azurerm_service_plan.appserviceplan.id
  https_only            = true
  site_config { 
    minimum_tls_version = "1.2"
  }
}

resource "azurerm_app_service_virtual_network_swift_connection" "vnint" {
  app_service_id = azurerm_linux_web_app.webapp.id
  subnet_id      = azurerm_subnet.sn1.id
}

# Create dev app
resource "azurerm_linux_web_app" "webapp2" {
  name                  = "surreylm-dev-app"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  service_plan_id       = azurerm_service_plan.appserviceplan.id
  https_only            = true
  site_config { 
    minimum_tls_version = "1.2"
  }
}

resource "azurerm_app_service_virtual_network_swift_connection" "vnint" {
  app_service_id = azurerm_linux_web_app.webapp2.id
  subnet_id      = azurerm_subnet.sn1.id
}