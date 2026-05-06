resource "aws_vpc" "myvpc" {
  cidr_block = var.cidr
}

# Creating Subnets
resource "aws_subnet" "subnet1" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "subnet2" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
}

# Creating Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.myvpc.id
}

#Creating Route Tables and Configuration
resource "aws_route_table" "RT" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "RTA1" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.RT.id
}

resource "aws_route_table_association" "RTA2" {
  subnet_id      = aws_subnet.subnet2.id
  route_table_id = aws_route_table.RT.id
}

#Creating Security Group
resource "aws_security_group" "myWebSg" {
  name        = "myWebSg"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.myvpc.id

  tags = {
    Name = "myWebSg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "forhttp" {
  description       = "HTTP from VPC"
  security_group_id = aws_security_group.myWebSg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "forssh" {
  description       = "SSH from VPC"
  security_group_id = aws_security_group.myWebSg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}


resource "aws_vpc_security_group_egress_rule" "foralloutbound" {
  security_group_id = aws_security_group.myWebSg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

#Creating S3 bucket
resource "aws_s3_bucket" "mytestprojects3" {
  bucket = "mytestprojects3"

  tags = {
    Name        = "My bucket"
    Environment = "Project"
  }
}

#Creating Instances
resource "aws_instance" "webserver1" {
  ami                    = "ami-04b70fa74e45c3917"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.myWebSg.id]
  subnet_id              = aws_subnet.subnet1.id
  user_data              = file("userdata.sh")
  tags = {
    Name = "WebServer1"
  }
}

resource "aws_instance" "webserver2" {
  ami                    = "ami-04b70fa74e45c3917"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.myWebSg.id]
  subnet_id              = aws_subnet.subnet2.id
  user_data              = file("userdata1.sh")
  tags = {
    Name = "WebServer2"
  }
}

#Create ALb
resource "aws_alb" "myalb" {
  name               = "my-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = [aws_subnet.subnet1.id, aws_subnet.subnet2.id]
  security_groups    = [aws_security_group.myWebSg.id]
  tags = {
    name = "web"
  }
}

# Creating Target group
resource "aws_lb_target_group" "mytg" {
  name     = "mytg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.myvpc.id

  health_check {
    interval = 30
    path     = "/"
    port     = "traffic-port"
  }
}

resource "aws_lb_target_group_attachment" "attach1" {
  target_group_arn = aws_lb_target_group.mytg.arn
  target_id        = aws_instance.webserver1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "attach2" {
  target_group_arn = aws_lb_target_group.mytg.arn
  target_id        = aws_instance.webserver2.id
  port             = 80
}

# Adding a Listner
resource "aws_lb_listener" "mylistner" {
  load_balancer_arn = aws_alb.myalb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.mytg.arn
    type             = "forward"
  }
}

#Output Value
output "loadbalancerdns" {
  value = aws_alb.myalb.dns_name
}
