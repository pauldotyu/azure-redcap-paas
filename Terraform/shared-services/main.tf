provider "azurerm" {
  subscription_id = var.subscription_id

  features {}
}

# NOTE: There is a breaking change in Azure where FrontDoor resources cannot be deleted unless the CNAME is removed first
# Use this command as a workaround for now: az feature register --namespace Microsoft.Network --name BypassCnameCheckForCustomDomainDeletion

data "http" "ifconfig" {
  url = "http://ifconfig.me"
}

resource "azurerm_resource_group" "redcap" {
  name     = "rg-${var.resource_base_name}"
  location = var.location
  tags     = var.tags
}

# ##############################################
# # SENDGRID ACCOUNT
# ##############################################

# resource "random_integer" "redcap" {
#   min = 1
#   max = 2147483647
#   keepers = {
#     tags = jsonencode(var.tags)
#   }
# }

# resource "azurerm_template_deployment" "redcap" {
#   name                = "${var.resource_base_name}-${random_integer.redcap.result}"
#   resource_group_name = azurerm_resource_group.redcap.name
#   deployment_mode     = "Incremental"
#   template_body       = file("sendgrid.json")

#   parameters_body = jsonencode({
#     "name_prefix" : {
#       "value" : "sg-${var.resource_base_name}"
#     },
#     "password" : {
#       "value" : var.sendgrid_password
#     },
#     "acceptMarketingEmails" : {
#       "value" : var.sendgrid_acceptmarketingemails
#     },
#     "email" : {
#       "value" : var.sendgrid_email
#     },
#     "tags" : {
#       "value" : var.tags
#     }
#   })
# }

##################################
# AZURE FRONT DOOR
##################################

resource "azurerm_frontdoor" "redcap" {
  name                                         = local.front_door_name
  friendly_name                                = local.front_door_name
  resource_group_name                          = azurerm_resource_group.redcap.name
  enforce_backend_pools_certificate_name_check = true
  backend_pools_send_receive_timeout_seconds   = 30
  tags                                         = var.tags

  # FRONTENDS
  frontend_endpoint {
    name      = "${local.front_door_name}-azurefd-net"
    host_name = "${local.front_door_name}.azurefd.net"
  }

  dynamic "frontend_endpoint" {
    for_each = var.sites
    content {
      name      = frontend_endpoint.value["name"]
      host_name = frontend_endpoint.value["host_name"]
    }
  }

  # BACKEND POOLS
  dynamic "backend_pool" {
    for_each = var.sites
    content {
      name                = backend_pool.value["name"]
      load_balancing_name = backend_pool.value["name"]
      health_probe_name   = backend_pool.value["name"]

      backend {
        address     = backend_pool.value["backend_address"]
        host_header = backend_pool.value["backend_address"]
        https_port  = "443"
        http_port   = "80"
      }
    }
  }

  dynamic "backend_pool_health_probe" {
    for_each = var.sites
    content {
      interval_in_seconds = 30
      name                = backend_pool_health_probe.value["name"]
      probe_method        = "HEAD"
      protocol            = "Https"
    }
  }

  dynamic "backend_pool_load_balancing" {
    for_each = var.sites
    content {
      name = backend_pool_load_balancing.value["name"]
    }
  }

  # ROUTING RULES - THESE CAN TAKE A FEW MINUTES TO UPDATE THROUGHOUT THE POPS
  dynamic "routing_rule" {
    for_each = var.sites
    content {
      name               = "${routing_rule.value["name"]}-root"
      accepted_protocols = ["Http", "Https"]
      patterns_to_match  = ["/"]
      frontend_endpoints = [routing_rule.value["name"]]

      redirect_configuration {
        custom_host       = "www.project-redcap.org"
        custom_path       = "/"
        redirect_protocol = "HttpsOnly"
        redirect_type     = "Moved"
      }
    }
  }

  dynamic "routing_rule" {
    for_each = var.sites
    content {
      name               = "${routing_rule.value["name"]}-surveys"
      accepted_protocols = ["Http", "Https"]
      patterns_to_match  = ["/surveys/*"]
      frontend_endpoints = [routing_rule.value["name"]]

      forwarding_configuration {
        backend_pool_name             = routing_rule.value["name"]
        forwarding_protocol           = "MatchRequest"
        cache_enabled                 = false
        cache_use_dynamic_compression = false
      }
    }
  }

  dynamic "routing_rule" {
    for_each = var.sites
    content {
      name               = "${routing_rule.value["name"]}-resources"
      accepted_protocols = ["Http", "Https"]
      patterns_to_match  = ["/redcap_v11.0.1/Resources/*"]
      frontend_endpoints = [routing_rule.value["name"]]

      forwarding_configuration {
        backend_pool_name             = routing_rule.value["name"]
        forwarding_protocol           = "MatchRequest"
        cache_enabled                 = false
        cache_use_dynamic_compression = false
      }
    }
  }
}

resource "azurerm_frontdoor_custom_https_configuration" "redcap" {
  for_each                          = { for s in var.sites : s.name => s }
  frontend_endpoint_id              = azurerm_frontdoor.redcap.frontend_endpoints[each.value["name"]]
  custom_https_provisioning_enabled = true

  custom_https_configuration {
    certificate_source = "FrontDoor"
  }
}