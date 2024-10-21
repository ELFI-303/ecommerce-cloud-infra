terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "eu-west-3"
  access_key = "AKIAWCYX7W3FGH4U4TQD"
  secret_key = "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"
}

# 1. Créer le VPC
resource "aws_vpc" "ecomm-vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "my-vpc"
  }
}

# 2. Créer le sous-réseau public
resource "aws_subnet" "public_subnet" {
  vpc_id            = aws_vpc.ecomm-vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "eu-west-3a"
  map_public_ip_on_launch = true  # Associer automatiquement des IP publiques aux instances dans ce sous-réseau


  tags = {
    Name = "public-subnet"
  }
}

resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.ecomm-vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "eu-west-3b"

  tags = {
    Name = "private-subnet"
  }
}

# 3. Créer l'Internet Gateway
resource "aws_internet_gateway" "ecomm_gateway" {
  vpc_id = aws_vpc.ecomm-vpc.id

  tags = {
    Name = "ecomm-gateway"
  }
}
# 4. Créer la table de routage
resource "aws_route_table" "public_ecomm_route_table" {
  vpc_id = aws_vpc.ecomm-vpc.id

  tags = {
    Name = "ecomm-route-table"
  }
}

# 5. Ajouter une route vers l'Internet Gateway dans la table de routage
resource "aws_route" "internet_access" {
  route_table_id         = aws_route_table.public_ecomm_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.ecomm_gateway.id
}

# 6. Associer la table de routage au sous-réseau public
resource "aws_route_table_association" "public_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_ecomm_route_table.id
}



# Créer un groupe de sécurité qui autorise le trafic HTTP
resource "aws_security_group" "allow_http" {
  name        = "allow_http"
  description = "Allow HTTP inbound traffic"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_http"
  }
  vpc_id = aws_vpc.ecomm-vpc.id

}

resource "aws_instance" "ecommerce-ec2-test-tf" {
  ami           = "ami-04a790ca5ad2f097c"  # Amazon Linux 2 ou Ubuntu AMI
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_subnet.id
  associate_public_ip_address = true
  # Groupe de sécurité pour autoriser HTTP (port 80)
  vpc_security_group_ids = [aws_security_group.allow_http.id]

  # User data pour installer Nginx à la création de l'instance
  user_data = <<-EOF
              #!/bin/bash
              sudo amazon-linux-extras update -y
              sudo amazon-linux-extras install nginx1 -y
              sudo systemctl start nginx
              sudo systemctl enable nginx
              sudo reboot
              EOF


  tags = {
    Name = "Ecommerce-EC2"
  }
}

resource "aws_instance" "replicate-ecommerce-ec2-test-tf" {
  ami           = "ami-04a790ca5ad2f097c"  # Amazon Linux 2 ou Ubuntu AMI
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_subnet.id
  associate_public_ip_address = true
  # Groupe de sécurité pour autoriser HTTP (port 80)
  vpc_security_group_ids = [aws_security_group.allow_http.id]

  # User data pour installer Nginx à la création de l'instance
  user_data = <<-EOF
              #!/bin/bash
              sudo amazon-linux-extras update -y
              sudo amazon-linux-extras install nginx1 -y
              sudo systemctl start nginx
              sudo systemctl enable nginx
              sudo reboot
              EOF
  

  tags = {
    Name = "Replicate-Ecommerce-EC2"
  }
}
