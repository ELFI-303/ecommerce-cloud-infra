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
    Name = "public_subnet"
  }
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id            = aws_vpc.ecomm-vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "eu-west-3b"
  map_public_ip_on_launch = true

  tags = {
    Name = "public_subnet_2"
  }
}

resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.ecomm-vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "eu-west-3b"

  tags = {
    Name = "private_subnet"
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


# 6. Associer la table de routage au sous-réseau public
resource "aws_route_table_association" "public_association_2" {
  subnet_id      = aws_subnet.public_subnet_2.id
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
  #associate_public_ip_address = true
  # Groupe de sécurité pour autoriser HTTP (port 80)
  vpc_security_group_ids = [aws_security_group.allow_http.id]

  # User data pour installer Nginx à la création de l'instance
  user_data = <<-EOF
              #!/bin/bash
              sudo amazon-linux-extras update -y
              sudo amazon-linux-extras install nginx1 -y
              echo "<html><body><h1>Instance 1: EC2 Ecommerce</h1></body></html>" > /usr/share/nginx/html/index.html
              sudo systemctl start nginx
              sudo systemctl enable nginx
              sudo reboot
              EOF


  tags = {
    Name = "Ecommerce-EC2-test-tf"
  }
}

resource "aws_instance" "replicate-ecommerce-ec2-test-tf" {
  ami           = "ami-04a790ca5ad2f097c"  # Amazon Linux 2 ou Ubuntu AMI
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_subnet.id
  #associate_public_ip_address = true
  # Groupe de sécurité pour autoriser HTTP (port 80)
  vpc_security_group_ids = [aws_security_group.allow_http.id]

  # User data pour installer Nginx à la création de l'instance
  user_data = <<-EOF
              #!/bin/bash
              sudo amazon-linux-extras update -y
              sudo amazon-linux-extras install nginx1 -y
              echo "<html><body><h1>Instance 2: Replicate EC2</h1></body></html>" > /usr/share/nginx/html/index.html
              sudo systemctl start nginx
              sudo systemctl enable nginx
              sudo reboot
              EOF
  

  tags = {
    Name = "Replicate-Ecommerce-EC2-test-tf"
  }
}



# Groupe cible pour les instances EC2
resource "aws_lb_target_group" "ecommerce_tg" {
  name     = "ecommerce-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.ecomm-vpc.id

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/"
    matcher             = "200"
  }

  tags = {
    Name = "Ecommerce-TG"
  }
}

# Load Balancer
resource "aws_lb" "ecommerce_lb" {
  name               = "ecommerce-alb"
  internal           = false  # Pour un ALB externe
  load_balancer_type = "application"
  security_groups    = [aws_security_group.allow_http.id]
  subnets            = [
   aws_subnet.public_subnet.id,  # Sous-réseau public 1
   aws_subnet.public_subnet_2.id  # Sous-réseau public 2
  ]
  tags = {
    Name = "Ecommerce-ALB"
  }
}



# Listener pour l'ALB (port 80)
resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.ecommerce_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecommerce_tg.arn
  }
}

# Associer les instances EC2 au groupe cible
resource "aws_lb_target_group_attachment" "ecommerce_ec2_attachment" {
  target_group_arn = aws_lb_target_group.ecommerce_tg.arn
  target_id        = aws_instance.ecommerce-ec2-test-tf.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "replicate_ec2_attachment" {
  target_group_arn = aws_lb_target_group.ecommerce_tg.arn
  target_id        = aws_instance.replicate-ecommerce-ec2-test-tf.id
  port             = 80
}


# 3. Créer un groupe de sécurité pour le SSH
resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow SSH inbound traffic"
  vpc_id      = aws_vpc.ecomm-vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Remplacez par votre adresse IP publique
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_ssh"
  }
}


# Ajouter Cognito User Pool pour gérer les utilisateurs
resource "aws_cognito_user_pool" "user_pool" {
  name = "ecommerce-user-pool"

  # Configuration minimale, peut être étendue selon les besoins
  auto_verified_attributes = ["email"]

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = false
    require_uppercase = true
  }

  tags = {
    Name = "ecommerce-user-pool"
  }
}

# Créer une application client Cognito (pour permettre à l'application d'interagir avec le User Pool)
resource "aws_cognito_user_pool_client" "user_pool_client" {
  user_pool_id = aws_cognito_user_pool.user_pool.id
  name         = "ecommerce-app-client"
  generate_secret = false

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_SRP_AUTH"
  ]

}

# Créer un rôle IAM pour les utilisateurs administrateurs
resource "aws_iam_role" "admin_role" {
  name = "ecommerce-admin-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRoleWithWebIdentity"
      Effect = "Allow"
      Principal = {
        Federated = "cognito-identity.amazonaws.com"
      }
      Condition = {
        StringEquals = {
          "cognito-identity.amazonaws.com:aud" = aws_cognito_user_pool_client.user_pool_client.id
        }
        "ForAnyValue:StringLike" = {
          "cognito-identity.amazonaws.com:amr" = "admin"
        }
      }
    }]
  })

  tags = {
    Name = "ecommerce-admin-role"
  }
}

# Créer un rôle IAM pour les utilisateurs clients
resource "aws_iam_role" "client_role" {
  name = "ecommerce-client-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRoleWithWebIdentity"
      Effect = "Allow"
      Principal = {
        Federated = "cognito-identity.amazonaws.com"
      }
      Condition = {
        StringEquals = {
          "cognito-identity.amazonaws.com:aud" = aws_cognito_user_pool_client.user_pool_client.id
        }
        "ForAnyValue:StringLike" = {
          "cognito-identity.amazonaws.com:amr" = "client"
        }
      }
    }]
  })

  tags = {
    Name = "ecommerce-client-role"
  }
}

# Définir les stratégies de groupe pour les rôles
resource "aws_iam_policy" "admin_policy" {
  name = "ecommerce-admin-policy"
  description = "Politique pour les administrateurs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "ec2:*",
        Effect = "Allow",
        Resource = "*"
      },
      {
        Action = "s3:*",
        Effect = "Allow",
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_policy" "client_policy" {
  name = "ecommerce-client-policy"
  description = "Politique pour les clients"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "ec2:Describe*",
        Effect = "Allow",
        Resource = "*"
      },
      {
        Action = "s3:GetObject",
        Effect = "Allow",
        Resource = "*"
      }
    ]
  })
}

# Attacher les stratégies aux rôles
resource "aws_iam_role_policy_attachment" "admin_policy_attach" {
  role       = aws_iam_role.admin_role.name
  policy_arn = aws_iam_policy.admin_policy.arn
}

resource "aws_iam_role_policy_attachment" "client_policy_attach" {
  role       = aws_iam_role.client_role.name
  policy_arn = aws_iam_policy.client_policy.arn
}

# Provisionner des utilisateurs Cognito après la création du user pool
resource "null_resource" "create_cognito_users" {
  provisioner "local-exec" {
    command = <<EOT
      aws cognito-idp admin-create-user --user-pool-id ${aws_cognito_user_pool.user_pool.id} --username brice --user-attributes Name=email,Value=brice.redon@etu.imt-nord-europe.fr --temporary-password "Brice#1234"
      aws cognito-idp admin-create-user --user-pool-id ${aws_cognito_user_pool.user_pool.id} --username elouan --user-attributes Name=email,Value=elouan.filleau@etu.imt-nord-europe.fr --temporary-password "Elouan#1234"
      aws cognito-idp admin-create-user --user-pool-id ${aws_cognito_user_pool.user_pool.id} --username elie --user-attributes Name=email,Value=elie.devriendt@etu.imt-nord-europe.fr --temporary-password "Elie#1234"
      aws cognito-idp admin-create-user --user-pool-id ${aws_cognito_user_pool.user_pool.id} --username admin --user-attributes Name=email,Value=admin@example.com --temporary-password "Admin#1234"
    EOT
  }
  
  depends_on = [aws_cognito_user_pool.user_pool]
}