variable "subscription_id" {
  type = string
}

variable "location" {
  type = string
}

variable "resource_prefix" {
  type = string
}

variable "resource_base_name" {
  type = string
}

variable "tags" {
  type = map(any)
}

variable "sendgrid_password" {
  type      = string
  sensitive = true
}

variable "sendgrid_acceptmarketingemails" {
  type = bool
}

variable "sendgrid_email" {
  type = string
}

variable "vnet_peerings" {
  type = list(object({
    peering_name = string
    resource_id  = string
  }))
  description = "List of virtual networks peers"
}

# dynamic sites to frontend
variable "sites" {
  type = list(object({
    name            = string
    host_name       = string
    backend_address = string
  }))
  description = "List of sites to configure on the FrontDoor"
}