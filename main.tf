#vpc
resource "aws_vpc" "this" {
  cidr_block = var.vpc_cidr
}



#public subnets
resource "aws_subnet" "public1" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = "10.1.1.0/24"
  availability_zone = var.az_a
}
resource "aws_subnet" "public2" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = "10.1.2.0/24"
  availability_zone = var.az_b
}

#private subnets
resource "aws_subnet" "private1" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = "10.1.3.0/24"
  availability_zone = var.az_a
}
resource "aws_subnet" "private2" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = "10.1.4.0/24"
  availability_zone = var.az_b
}



#igw - public route table use
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
}

#eip - for nat gw
resource "aws_eip" "this1" {
}

resource "aws_eip" "this2" {
}

#nat gw - connect private subnet to public
resource "aws_nat_gateway" "this1" {
  allocation_id = aws_eip.this1.id
  subnet_id     = aws_subnet.public1.id
}

resource "aws_nat_gateway" "this2" {
  allocation_id = aws_eip.this2.id
  subnet_id     = aws_subnet.public2.id
}



#route tables
#public - to igw
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = var.all_traffic_cidr
    gateway_id = aws_internet_gateway.this.id
  }
}

#private - to public subnet via nat gw
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = var.all_traffic_cidr
    nat_gateway_id = aws_nat_gateway.this1.id
  }

  route {
    cidr_block     = var.all_traffic_cidr
    nat_gateway_id = aws_nat_gateway.this2.id
  }
}

#associations - 1 for each subnet
#public
resource "aws_route_table_association" "public1" {
  subnet_id      = aws_subnet.public1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public2" {
  subnet_id      = aws_subnet.public2.id
  route_table_id = aws_route_table.public.id
}

#private
resource "aws_route_table_association" "private1" {
  subnet_id      = aws_subnet.private1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private2" {
  subnet_id      = aws_subnet.private2.id
  route_table_id = aws_route_table.private.id
}



#security group - port 80 traffic
resource "aws_security_group" "this" {
  vpc_id = aws_vpc.this.id
}

resource "aws_vpc_security_group_ingress_rule" "this" {
  security_group_id = aws_security_group.this.id
  cidr_ipv4         = var.all_traffic_cidr
  to_port           = 80
  from_port         = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "this" {
  security_group_id = aws_security_group.this.id
  cidr_ipv4         = var.all_traffic_cidr
  to_port           = 0
  from_port         = 0
  ip_protocol       = -1
}

data "aws_ami" "this" {
  most_recent = true

  filter {
    name   = "name"
    values = ["al2023 2024-*"]
  }

  owners = ["735779405961"]
}

resource "aws_launch_template" "this" {
  name_prefix   = "hello-world"
  image_id      = data.aws_ami.this.id
  instance_type = "t2.micro"

  vpc_security_group_ids = [aws_security_group.this.id]
}

#asg
resource "aws_autoscaling_group" "hello_world" {
  desired_capacity     = 1
  min_size             = 1
  max_size             = 2
  launch_template {
    id      = aws_launch_template.this.id
    version = "$Latest"
  }

  #keep instances in private subnets
  vpc_zone_identifier = [aws_subnet.private1.id, aws_subnet.private2.id]
  #attach target group - listeners now routed here
  target_group_arns = [aws_lb_target_group.this.arn]
}



#alb
resource "aws_lb" "this" {
  name = "alb"
  #make it internet-facing
  internal                         = false
  load_balancer_type               = "application"
  security_groups                  = [aws_security_group.this.id]
  subnets                          = [aws_subnet.public1.id, aws_subnet.public2.id]
  enable_cross_zone_load_balancing = true
}

#target group - attached to asg; distributes traffic from alb to asg
resource "aws_lb_target_group" "this" {
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.this.id
}

#alb listener - reading traffic
resource "aws_lb_listener" "this" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "OK"
      status_code  = "200"
    }
  }
}

#alb listener rule - forwarding to target group
resource "aws_lb_listener_rule" "this" {
  listener_arn = aws_lb_listener.this.arn

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }

  condition {
    path_pattern {
      values = ["/"]
    }
  }
}
