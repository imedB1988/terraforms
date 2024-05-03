provider "aws" {
  region = "eu-north-1"
}

#1 create VPC 

resource "aws_vpc" "terraVPC" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name="terraVPC"
  }
}

#2 Configure internet gateway

resource "aws_internet_gateway" "igw" {
 vpc_id = aws_vpc.terraVPC.id
tags = {
  Name="igw"
}
}

#3 create route table

resource "aws_route_table" "awsroutetable" {
    vpc_id = aws_vpc.terraVPC.id
    route {
        cidr_block="0.0.0.0/0"
        gateway_id=aws_internet_gateway.igw.id
    }
    
    tags = {
      Name="awsroutetable"
    } 
}

#4 create subnet
resource "aws_subnet" "awssubnet" {
  vpc_id = aws_vpc.terraVPC.id
  cidr_block = "10.0.0.0/24"
  depends_on = [ aws_internet_gateway.igw ]

  tags = {
    Name="awssubnet"
  }
}


#5 Associate subnet with route table

resource "aws_route_table_association" "awsroutetableassoc" {
    subnet_id = aws_subnet.awssubnet.id
    route_table_id = aws_route_table.awsroutetable.id
    }

#6 create a security group to allow 22, 80, 443
resource "aws_security_group" "securitygroup" {
  name="awssecuritygroup"
  description = "Allow SSH, HTTP, HTTPS, inbound traffic"
  vpc_id = aws_vpc.terraVPC.id  
  ingress {
    description="HTTPS on VPC"
    from_port=443
    to_port=443
    protocol="tcp"
    cidr_blocks=["0.0.0.0/0"]
  }

  ingress {
    description="HTTP on VPC"
    from_port=80
    to_port=80
    protocol="tcp"
    cidr_blocks=["0.0.0.0/0"]
  }

  ingress {
    description="SSH on VPC"
    from_port=22
    to_port=22
    protocol="tcp"
    cidr_blocks=["0.0.0.0/0"]
  }

  egress {
    from_port=0
    to_port=0
    protocol="-1"
    cidr_blocks=["0.0.0.0/0"]
  }

  tags ={
    Name="SecurityGroup"
  }
}

#7 Assign Elastic Network Interface with IP
resource "aws_network_interface" "eni_terraVPC" {
  subnet_id = aws_subnet.awssubnet.id
  private_ips = ["10.0.0.10"]
  security_groups = [ aws_security_group.securitygroup.id ]

}

#8 Assign Elastic IP with ENI
resource "aws_eip" "awseip" {
  vpc = true
  network_interface = aws_network_interface.eni_terraVPC.id
  associate_with_private_ip="10.0.0.10"
  depends_on = [ aws_internet_gateway.igw, aws_instance.apache_instance]
  tags = {
    Name="awseip"
  }
}

#9 Create IAM Role to access S3
resource "aws_iam_role" "EC2-S3" {
  name = "EC2-S3"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    tag-key = "tag-value"
  }
}

resource "aws_iam_instance_profile" "EC2-S3_profile" {
  name = "EC2-S3profile"
  role = "${aws_iam_role.EC2-S3.name}"
}




resource "aws_instance" "apache_instance" {
  ami = "ami-0705384c0b33c194c"
  instance_type = "t3.micro"
  key_name = "terraformkey"
  iam_instance_profile = "${aws_iam_instance_profile.EC2-S3_profile.name}"
  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.eni_terraVPC.id
  }

  user_data = <<-EOF
    #!/bin/bash
    sudo yum update
    sudo yum install -y httpd.x86_64
    sudo systemctl start httpd.service
    sudo systemctl enable httpd.service
    sudo aws s3 sync s3://awss3bucket88/website /var/www/html
    EOF

    tags = {
      Name="test_instance 1.0"
    }
}

#aws ec2 create-key-pair --key-name terraformkey --query 'KeyMaterial' --output text > terraform.pem
