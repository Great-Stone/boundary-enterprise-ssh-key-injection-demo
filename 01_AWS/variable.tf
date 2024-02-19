variable "default_tags" {
  default = {
    purpose = "boundary ent test"
  }
}

variable "boundary_lic_path" {}

variable "boundary_admin_username" {
  default = "admin"
}

variable "boundary_admin_password" {
  default = "password"
}