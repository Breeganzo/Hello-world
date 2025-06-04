provider "aws" {
  region = "us-east-1"   # Change to your preferred region
}

#Automatically generate new key pair
resource "tls_private_key" "example_key" {
    algorithm = "RSA"
    rsa_bits = 4096
}

resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = tls_private_key.example_key.public_key_openssh  # Your local public SSH key
}

resource "local_file" "private_key" {
    content = tls_private_key.example_key.private_key_pem
    filename = "${aws_key_pair.deployer.key_name}.pem"
}

resource "aws_instance" "flask_instance" {
  ami           = "ami-0e449927258d45bc4"
  instance_type = "t2.micro"
  key_name      = aws_key_pair.deployer.key_name
  security_groups = [aws_security_group.flask_sg.name]
  associate_public_ip_address = true

  connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("${path.module}/${aws_key_pair.deployer.key_name}.pem")
      host        = self.public_ip
    }

  provisioner "file" {
    source      = "app.py"
    destination = "/home/ec2-user/app.py"
  }

provisioner "remote-exec" {
    inline = [
      "sudo yum update -y",
      "sudo yum install -y python3 python3-pip",
      "sudo pip3 install --upgrade flask",
      "echo 'export PATH=$PATH:/usr/local/bin' | sudo tee -a /etc/profile",
      "cd /home/ec2-user",
      "bash -c 'nohup /usr/bin/python3 /home/ec2-user/app.py > /home/ec2-user/app.log 2>&1 < /dev/null &'",
      "sleep 5"
    ]
  }
  
  tags = {
    Name = "FlaskAppInstance"
  }
}


resource "aws_security_group" "flask_sg" {
  name        = "flask_sg"
  description = "Allow HTTP and SSH inbound traffic"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # SSH from anywhere (adjust for security)
  }

  ingress {
    description = "Python - HTTP"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Flask default port
  }

  ingress{
    description = "HTTP"
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

output "public_ip" {
  value = aws_instance.flask_instance.public_ip
  description = "Public IP of the EC2 instance"
}