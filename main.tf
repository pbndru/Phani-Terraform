provider "aws" {
  region = "us-east-1"
  access_key = "AKIAZROIAOKYNODJ5ZVG"
  secret_key = "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"
}

# 1. Create VPC
resource "aws_vpc" "phani_vpc" {
    cidr_block = "10.0.0.0/16"
    tags = {
      Name = "developer-vpc"
    }
}

# 2. Create Internet Gateway
resource "aws_internet_gateway" "phani_gateway" {
  vpc_id = aws_vpc.phani_vpc.id
}

# 3. Create route table
resource "aws_route_table" "phani_route_table" {
  vpc_id =  aws_vpc.phani_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.phani_gateway.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.phani_gateway.id
  }

  tags = {
    Name = "developer-route"
  }
}

variable "subnet_prefix" {
    description = "cidr block for subnet"
    type = string
}
\
# 4. Create subnet
resource "aws_subnet" "phani_subnet" {
  vpc_id = aws_vpc.phani_vpc.id
  cidr_block = var.subnet_prefix
  availability_zone = "us-east-1a"
  
  tags = {
    Name = "developer-subnet"
  }
}

# 5. Associate subnet with Route table
resource "aws_route_table_association" "phani_route_table_association" {
  subnet_id      = aws_subnet.phani_subnet.id
  route_table_id = aws_route_table.phani_route_table.id
}

# 6. Create security group to allow port 22, 80, 443
resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow web inbound traffic"
  vpc_id      = aws_vpc.phani_vpc.id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

   ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] //any ip adress
  }

   ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_web"
  }
}

# 7. create a network interface with an ip in the subnet that was created in step 4
resource "aws_network_interface" "web_server_nic" {
  subnet_id       = aws_subnet.phani_subnet.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]


}

# 8. Assign an elastic IP to the network interface crated in step 7
resource "aws_eip" "one" {
  vpc                       = "true"
  network_interface         = aws_network_interface.web_server_nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on                = [aws_internet_gateway.phani_gateway]
}

output "phani_server_public_ip" {
    value = aws_eip.one.public_ip
}

# 9. Cretae ubuntu server and install/enable apache2
resource "aws_instance" "web-server-instance" {
    ami = "ami-0e731c8a588258d0d"
    instance_type = "t2.micro"
    availability_zone = "us-east-1a"
    key_name = "main-key"

    network_interface {
      device_index = 0
      network_interface_id = aws_network_interface.web_server_nic.id
    }

    user_data = <<-EOF
                #!/bin/bash
                sudo apt update -y
                sudo apt install apache2 -y
                sudo systemctl start apache2
                sudo bash -c 'echo web server > /var/www/html/index.html'
                EOF
    tags = {
        Name = "web-server"
    }
}