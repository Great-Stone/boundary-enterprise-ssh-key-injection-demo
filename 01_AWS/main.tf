provider "aws" {
  region = "ap-northeast-2"

  default_tags {
    tags = var.default_tags
  }
}

resource "aws_vpc" "boundary" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
}

data "aws_availability_zones" "available" {
  state = "available"
}

// public subnet
resource "aws_subnet" "public" {
  count             = 2
  vpc_id            = aws_vpc.boundary.id
  availability_zone = data.aws_availability_zones.available.names[count.index]
  cidr_block        = cidrsubnet(aws_vpc.boundary.cidr_block, 8, count.index) // "10.0.0.0/24" & "10.0.1.0/24"
}

resource "aws_internet_gateway" "public" {
  vpc_id = aws_vpc.boundary.id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.boundary.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.public.id
  }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_eip" "public" {
  count  = 2
  domain = "vpc"
}

resource "aws_nat_gateway" "public" {
  count         = 2
  allocation_id = aws_eip.public[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
}

// private subnet
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.boundary.id
  availability_zone = data.aws_availability_zones.available.names[count.index]
  cidr_block        = cidrsubnet(aws_vpc.boundary.cidr_block, 8, count.index + 10) // "10.0.10.0/24" & "10.0.11.0/24"
}

resource "aws_route_table" "private" {
  count  = 2
  vpc_id = aws_vpc.boundary.id
}

resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

resource "aws_route" "private" {
  count                  = 2
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.public[count.index].id
}

data "http" "my_ip" {
  url = "https://checkip.amazonaws.com/"
}

// SG
resource "aws_security_group" "public" {
  name   = "public"
  vpc_id = aws_vpc.boundary.id

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_security_group_rule" "http" {
  type      = "ingress"
  from_port = 80
  to_port   = 80
  protocol  = "tcp"
  cidr_blocks = [
    aws_vpc.boundary.cidr_block,
    "${trimspace(data.http.my_ip.response_body)}/32"
  ]
  security_group_id = aws_security_group.public.id
}

resource "aws_security_group_rule" "https" {
  type      = "ingress"
  from_port = 443
  to_port   = 443
  protocol  = "tcp"
  cidr_blocks = [
    aws_vpc.boundary.cidr_block,
    "${trimspace(data.http.my_ip.response_body)}/32"
  ]
  security_group_id = aws_security_group.public.id
}

resource "aws_security_group_rule" "boundary" {
  type      = "ingress"
  from_port = 9200
  to_port   = 9203
  protocol  = "tcp"
  cidr_blocks = [
    aws_vpc.boundary.cidr_block,
    "${trimspace(data.http.my_ip.response_body)}/32"
  ]
  security_group_id = aws_security_group.public.id
}

resource "aws_security_group_rule" "ssh" {
  type      = "ingress"
  from_port = 22
  to_port   = 22
  protocol  = "tcp"
  cidr_blocks = [
    aws_vpc.boundary.cidr_block,
    "${trimspace(data.http.my_ip.response_body)}/32"
  ]
  security_group_id = aws_security_group.public.id
}

resource "aws_security_group" "private" {
  name   = "private"
  vpc_id = aws_vpc.boundary.id

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_security_group_rule" "private_ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = aws_subnet.public[*].cidr_block
  security_group_id = aws_security_group.private.id
}

// key pair
resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_sensitive_file" "ssh_private" {
  content  = tls_private_key.ssh.private_key_pem
  filename = "${path.module}/ssh_private"
}

resource "random_id" "key_id" {
  keepers = {
    ami_id = tls_private_key.ssh.public_key_openssh
  }

  byte_length = 8
}

resource "aws_key_pair" "ssh" {
  key_name   = "key-${random_id.key_id.hex}"
  public_key = tls_private_key.ssh.public_key_openssh
}

// EC2
data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "boundary" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "m7i.xlarge"
  key_name                    = aws_key_pair.ssh.key_name
  subnet_id                   = aws_subnet.public[0].id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.public.id]

  user_data = templatefile("${path.module}/user_data.tpl", {
    boundary_admin_username = var.boundary_admin_username
    boundary_admin_password = var.boundary_admin_password
    boundady_license_txt = file(var.boundary_lic_path)
  })

  tags = {
    Name = "boundary"
  }
}

resource "terraform_data" "boundary" {
  triggers_replace = [
    aws_instance.boundary.public_ip
  ]

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = tls_private_key.ssh.private_key_pem
    host        = aws_instance.boundary.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "echo ====================================",
    ]
  }
}

resource "aws_instance" "private" {
  count                       = 2
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.micro"
  key_name                    = aws_key_pair.ssh.key_name
  subnet_id                   = aws_subnet.private[0].id
  associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.private.id]

  tags = {
    Name = "private"
  }
}