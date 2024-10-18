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


# Importer le VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}


resource "aws_subnet" "publique" {
  vpc_id            = aws_vpc.main.id  # VPC ID importé
  cidr_block        = "10.0.1.0/24"
  availability_zone = "eu-west-3a"  # Remplacez par la zone souhaitée

  tags = {
    Name = "ecommerce-subnet-1"
  }
}

resource "aws_subnet" "prive" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "eu-west-3b"

  tags = {
    Name = "ecommerce-subnet-2"
  }
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
  vpc_id = aws_vpc.main.id

}

resource "aws_instance" "ecommerce-ec2" {
  ami           = "ami-04a790ca5ad2f097c"  # Amazon Linux 2 ou Ubuntu AMI
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.prive.id

  # Groupe de sécurité pour autoriser HTTP (port 80)
  vpc_security_group_ids = [aws_security_group.allow_http.id]

  # User data pour installer Nginx à la création de l'instance
  user_data = <<-EOF
              #!/bin/bash
              sudo amazon-linux-extras update -y
              sudo amazon-linux-extras install nginx1 -y
              sudo systemctl start nginx
              sudo systemctl enable nginx
              EOF

    


  tags = {
    Name = "Ecommerce-EC2"
  }
}

resource "aws_instance" "replicate-ecommerce-ec2" {
  ami           = "ami-04a790ca5ad2f097c"  # Amazon Linux 2 ou Ubuntu AMI
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.prive.id
  # Groupe de sécurité pour autoriser HTTP (port 80)
  vpc_security_group_ids = [aws_security_group.allow_http.id]

  # User data pour installer Nginx à la création de l'instance
  user_data = <<-EOF
              #!/bin/bash
              sudo amazon-linux-extras update -y
              sudo amazon-linux-extras install nginx1 -y
              sudo systemctl start nginx
              sudo systemctl enable nginx
              EOF
  

  tags = {
    Name = "Replicate-Ecommerce-EC2"
  }
}

