data "terraform_remote_state" "aws" {
  backend = "local"

  config = {
    path = "../01_AWS/terraform.tfstate"
  }
}

locals {
  boundary_info   = data.terraform_remote_state.aws.outputs.boundary_info
  priavate_ips    = data.terraform_remote_state.aws.outputs.private_ips
  private_key_pem = data.terraform_remote_state.aws.outputs.private_key_pem
}


provider "boundary" {
  addr                   = local.boundary_info.boundary_addr
  auth_method_id         = "ampw_1234567890"
  auth_method_login_name = local.boundary_info.user
  auth_method_password   = local.boundary_info.pass
}

data "boundary_scope" "generated_org" {
  name     = "Generated org scope"
  scope_id = "global"
}

data "boundary_scope" "generated_prj" {
  name     = "Generated project scope"
  scope_id = data.boundary_scope.generated_org.id
}

# SSH KEY
resource "boundary_credential_store_static" "example" {
  name        = "example_static_credential_store"
  description = "My first static credential store!"
  scope_id    = data.boundary_scope.generated_prj.id
}

resource "boundary_credential_ssh_private_key" "example" {
  name                   = "example_ssh_private_key"
  description            = "My first ssh private key credential!"
  credential_store_id    = boundary_credential_store_static.example.id
  username               = "ubuntu"
  private_key            = local.private_key_pem
  private_key_passphrase = ""
}

# HOST
resource "boundary_host_catalog_static" "private" {
  name        = "My catalog"
  description = "My first host catalog!"
  scope_id    = data.boundary_scope.generated_prj.id
}

resource "boundary_host_static" "private" {
  count           = length(local.priavate_ips)
  name            = "host_${count.index}"
  description     = "My host - ${count.index}"
  address         = local.priavate_ips[count.index]
  host_catalog_id = boundary_host_catalog_static.private.id
}

resource "boundary_host_set_static" "private" {
  name            = "My host set"
  host_catalog_id = boundary_host_catalog_static.private.id
  host_ids        = [for host in boundary_host_static.private : host.id]
}

# Target
resource "boundary_target" "ssh_foo" {
  name         = "ssh_foo"
  description  = "Ssh target"
  type         = "ssh"
  default_port = "22"
  scope_id     = data.boundary_scope.generated_prj.id
  host_source_ids = [
    boundary_host_set_static.private.id
  ]
  injected_application_credential_source_ids = [
    boundary_credential_ssh_private_key.example.id
  ]
}