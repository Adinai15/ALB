resource "aws_vpc" "vpc_hw_alb" {
  cidr_block = "10.0.0.0/24"
  tags = {
    Name = "vpc_hw_alb"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "public_alb" {
  vpc_id                  = aws_vpc.vpc_hw_alb.id
  cidr_block              = "10.0.0.0/25"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  tags = {
    Name = "public_alb"
  }
}

resource "aws_subnet" "public_alb2" {
  vpc_id                  = aws_vpc.vpc_hw_alb.id
  cidr_block              = "10.0.0.128/25"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true
  tags = {
    Name = "public_alb2"
  }
}
resource "aws_internet_gateway" "igw_alb" {
  vpc_id = aws_vpc.vpc_hw_alb.id

  tags = {
    Name = "igw"
  }
}

resource "aws_route_table" "for_alb_rtb" {
  vpc_id = aws_vpc.vpc_hw_alb.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw_alb.id
  }


  tags = {
    Name = "for_alb_rtb"
  }
}

resource "aws_route_table_association" "public_alb" {
  subnet_id      = aws_subnet.public_alb.id
  route_table_id = aws_route_table.for_alb_rtb.id
}

resource "aws_route_table_association" "public_alb2" {
  subnet_id      = aws_subnet.public_alb2.id
  route_table_id = aws_route_table.for_alb_rtb.id
}

data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-kernel-5.10-hvm*x86_64-gp2"]
  }
}

output "name" {
  value = data.aws_ami.amazon_linux_2.id
}

resource "aws_security_group" "public_alb_sgrp" {
  name        = "public-alb-sgrp"
  description = "public_alb_sgrp"
  vpc_id      = aws_vpc.vpc_hw_alb.id

  tags = {
    Name = "public_alb_sgrp"
  }
}

resource "aws_vpc_security_group_egress_rule" "all_outbound" {
  security_group_id = aws_security_group.public_alb_sgrp.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.public_alb_sgrp.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}


resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.public_alb_sgrp.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

data "aws_key_pair" "my-key" {
  key_name = "tentek"
}


resource "aws_instance" "public_alb_instance" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public_alb.id
  vpc_security_group_ids = [aws_security_group.public_alb_sgrp.id]
  key_name               = data.aws_key_pair.my-key.key_name
  user_data              = file("user_data.sh")



  tags = {
    Name = "public_alb_instance"
  }
}


resource "aws_instance" "public_alb2_instance" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public_alb2.id
  vpc_security_group_ids = [aws_security_group.public_alb_sgrp.id]
  key_name               = data.aws_key_pair.my-key.key_name
  user_data              = file("user_data.sh")



  tags = {
    Name = "public_alb2_instance"
  }
}

#Create Target Group
resource "aws_lb_target_group" "hw_alb_tgrp" {
  name     = "hw-alb-tgrp"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.vpc_hw_alb.id
}

resource "aws_lb_target_group_attachment" "public_alb_instance_to_hw_alb_tgrp" {
  target_group_arn = aws_lb_target_group.hw_alb_tgrp.arn
  target_id        = aws_instance.public_alb_instance.id
}

resource "aws_lb_target_group_attachment" "public_alb2_instance_to_hw_alb_tgrp" {
  target_group_arn = aws_lb_target_group.hw_alb_tgrp.arn
  target_id        = aws_instance.public_alb2_instance.id
}

### Create security group for alb:

resource "aws_security_group" "hw_alb_security_group" {
  name        = "hw-alb-security-group"
  description = "Allow HTTP&HTTPS from WWW"
  vpc_id      = aws_vpc.vpc_hw_alb.id
  tags        = { Name = "hw_alb_security_group" }


  ingress {
    description = "HTTP from WWW"
    from_port   = 80
    to_port     = 80
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }


  ingress {
    description = "HTTPS from WWW"
    from_port   = 443
    to_port     = 443
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}


### create ssl cert: 
resource "aws_acm_certificate" "my_cert_hw" {
  domain_name               = "kasiet.link"
  subject_alternative_names = ["projecthw.kasiet.link"]
  validation_method         = "DNS"



  tags = {
    Name = "my_cert_hw"
  }
}

### validate ssl cert:

resource "aws_route53_record" "hw_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.my_cert_hw.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = "Z0543846S4V3BA27H27Y"
}

### Create ALB:

resource "aws_lb" "hw_alb" {
  name               = "hw-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.hw_alb_security_group.id]
  subnets            = [aws_subnet.public_alb.id, aws_subnet.public_alb2.id]


  tags = {
    name = "hw_alb"
  }
}


#### Create http listener

resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.hw_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}


##### Create https listener

 resource "aws_alb_listener" "HTTPS_listener" {
  load_balancer_arn = aws_lb.hw_alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.my_cert_hw.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.hw_alb_tgrp.arn
  }
}



#### Create Cname

resource "aws_route53_record" "hw_record" {
  zone_id = "Z0543846S4V3BA27H27Y"
  name    = "projecthw.kasiet.link"
  type    = "CNAME"
  ttl     = 60
  records = [aws_lb.hw_alb.dns_name]
}
