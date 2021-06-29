subscription_id                = "<YOUR_DEPLOYMENT_SUBSCRIPTION_ID>"

vnet_peerings = [
  {
    peering_name = "to-hub-vnet"
    resource_id  = "<YOUR_HUB_VNET_RESOURCE_ID>"
  }
]

resource_prefix                = "contoso"
resource_base_name             = "redcap"
location                       = "westus2"
sendgrid_acceptmarketingemails = false
sendgrid_email                 = "pauyu@microsoft.com"

tags = {
  "po-number"          = "zzz"
  "environment"        = "prod"
  "mission"            = "administrative"
  "protection-level"   = "p1"
  "availability-level" = "a1"
}

## PLACE EACH REDCAP SITE INFO HERE. THE TF WILL ITERATE THROUGH EACH OBJECT AND CONFIGURE FRONTDOOR FRONTENDS AND BACKENDS
sites = [
  {
    name            = "redcapsample1"
    host_name       = "redcapsample1.contoso.work"
    backend_address = "asredcapsample1omhw.azurewebsites.net"
    redcap_version  = "11.0.1"
  }
]