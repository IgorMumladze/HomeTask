resource "aws_lb" "this" {
  name                       = "${local.base_name}-alb"
  load_balancer_type         = "application"
  internal                   = false
  security_groups            = [module.networking.alb_security_group_id]
  subnets                    = module.networking.public_subnet_ids
  enable_deletion_protection = var.alb_deletion_protection

  tags = merge(var.tags, {
    Name        = "${local.base_name}-alb"
    Project     = var.project_name
    Environment = var.environment
  })
}

resource "aws_lb_target_group" "this" {
  name        = "${local.base_name}-tg"
  port        = var.api_container_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = module.networking.vpc_id

  health_check {
    path                = var.health_check_path
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 30
    timeout             = 5
    matcher             = "200-399"
  }

  tags = merge(var.tags, {
    Name        = "${local.base_name}-tg"
    Project     = var.project_name
    Environment = var.environment
  })
}

resource "aws_lb_listener" "http" {
  count             = var.enable_https ? 0 : 1
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}

resource "aws_lb_listener" "http_redirect" {
  count             = var.enable_https ? 1 : 0
  load_balancer_arn = aws_lb.this.arn
  port              = 80
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

resource "aws_lb_listener" "https" {
  count             = var.enable_https ? 1 : 0
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.ssl_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}

