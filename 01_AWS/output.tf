output "boundary_info" {
  value = {
    boundary_addr = "http://${aws_instance.boundary.public_ip}:9200"
    user          = var.boundary_admin_username
    pass          = var.boundary_admin_password
  }
}

output "private_ips" {
  value = [for instance in aws_instance.private[*] : instance.private_ip]
}

output "private_key_pem" {
  value     = tls_private_key.ssh.private_key_pem
  sensitive = true
}