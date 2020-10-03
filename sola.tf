provider "aws" {
  region = "us-east-1"
}

# Create a VPC
resource "aws_vpc" "jpvpc" {
  cidr_block = "10.0.0.0/16"

 tags = {
    Name = "terra vpc"
  }

}
# create subnet
resource "aws_subnet" "subnet1" {
  vpc_id     = aws_vpc.jpvpc.id
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_launch         = true
  tags = {
    Name = "terra-public-subnet"
  }
 }

# create subnet2
resource "aws_subnet" "subnet2" {
  vpc_id     = aws_vpc.jpvpc.id
  cidr_block = "10.0.2.0/24"

  tags = {
    Name = "terra-private-subnet"
  }

}
#create IGW
resource "aws_internet_gateway" "terraGW" {
  vpc_id = "${aws_vpc.jpvpc.id}"

  tags = {
    Name = "terraGW"
  }
}
#create elastic ip  
resource "aws_eip" "terranat" {
  vpc      = true
}


# create NAT
resource "aws_nat_gateway" "terragw" {
  allocation_id = aws_eip.terranat.id
  subnet_id     = aws_subnet.subnet1.id

  tags = {
    Name = "terra NAT"
  }
}
#create Route table 
resource "aws_route_table" "terraroute" {
  vpc_id = aws_vpc.jpvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.terraGW.id
  }

  tags = {
    Name = "terraRT1"
  }
}

#create route table2
resource "aws_route_table" "terraroute2" {
  vpc_id = aws_vpc.jpvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.terragw.id
  }

  tags = {
    Name = "Terra_private_route"
  }
}
#enable subnet assoiation public subnet
resource "aws_route_table_association" "terraroute" {
  subnet_id      = "${aws_subnet.subnet1.id}"
  route_table_id = "${aws_route_table.terraroute.id}"
}
#enable subnet association to private subnet
resource "aws_route_table_association" "terraroute2" {
  subnet_id      = "${aws_subnet.subnet2.id}"
  route_table_id = "${aws_route_table.terraroute2.id}"
}
# create Security group for jump server
resource "aws_security_group" "terra-sh-jump" {
  vpc_id = aws_vpc.jpvpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
}

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["73.129.56.75/32"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
tags = {
    Name = "Terra-sh-jump"
  }

}

resource "aws_security_group" "terra-sh-private" {
  vpc_id = aws_vpc.jpvpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = ["${aws_security_group.terra-sh-jump.id}"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
tags = {
    Name = "Terra-sh-private"
  }

}
resource "aws_instance" "web" {
  ami           = "ami-000db10762d0c4c05"
  instance_type = "t2.micro"
  key_name = "hpkey"
  subnet_id      = "${aws_subnet.subnet1.id}"
  security_groups = ["${aws_security_group.terra-sh-jump.id}"]
  user_data = <<-EOF
	  #! /bin/bash
    sudo yum update -y
	  sudo yum install httpd -y
	  sudo systemctl start httpd
    EOF

  tags = {
    Name = "Sola terraform isntance"
  }
}
