# ECS Fargate Service behind the ALB
# Execution role + log group + Security Group + target group + listener rule + task definition + service.

# Task execution role - lets ECS pull the image from ECR and write the container logs
data "aws_iam_policy_document" "ecs_tasks_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "execution" {
  name               = "${local.service_full_name}-exec"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
  tags               = local.common_tags
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Container logs
resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/${data.terraform_remote_state.ecs_cluster.outputs.cluster_name}/${var.service_name}"
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}

# Security Group of the tasks - only the ALB reaches the container port
resource "aws_security_group" "tasks" {
  name        = "${local.service_full_name}-tasks-sg"
  description = "ECS tasks of ${var.service_name}: container port from the ALB, egress all"
  vpc_id      = data.terraform_remote_state.vpc.outputs.vpc_id
  tags        = merge(local.common_tags, { Name = "${local.service_full_name}-tasks-sg" })
}

resource "aws_vpc_security_group_ingress_rule" "from_alb" {
  security_group_id            = aws_security_group.tasks.id
  description                  = "Container port from the ALB"
  referenced_security_group_id = data.terraform_remote_state.alb.outputs.alb_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = var.container_port
  to_port                      = var.container_port
}

# Egress all - image pull from ECR and logs through the NAT Gateway
resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.tasks.id
  description       = "Allow all outbound IPv4 traffic"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# Target group - Fargate (awsvpc) registers the task IPs
resource "aws_lb_target_group" "this" {
  name                 = local.target_group_name
  port                 = var.container_port
  protocol             = "HTTP"
  target_type          = "ip"
  vpc_id               = data.terraform_remote_state.vpc.outputs.vpc_id
  deregistration_delay = 30

  health_check {
    path                = var.health_check_path
    matcher             = "200-399"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = local.common_tags
}

# Listener rule on the ALB HTTP :80 listener
resource "aws_lb_listener_rule" "this" {
  listener_arn = data.terraform_remote_state.alb.outputs.http_listener_arn
  priority     = var.listener_rule_priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }

  condition {
    path_pattern {
      values = var.path_patterns
    }
  }

  tags = local.common_tags
}

# Task definition - one container, Fargate, awsvpc
resource "aws_ecs_task_definition" "this" {
  family                   = local.service_full_name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.execution.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([
    {
      name      = var.service_name
      image     = local.image
      essential = true
      portMappings = [
        {
          containerPort = var.container_port
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.this.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = var.service_name
        }
      }
    }
  ])

  tags = local.common_tags
}

# ECS Service on Fargate, in the private subnets
resource "aws_ecs_service" "this" {
  name            = var.service_name
  cluster         = data.terraform_remote_state.ecs_cluster.outputs.cluster_arn
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = var.desired_count

  capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 100
    base              = 1
  }

  network_configuration {
    subnets          = data.terraform_remote_state.vpc.outputs.private_subnets
    security_groups  = [aws_security_group.tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.this.arn
    container_name   = var.service_name
    container_port   = var.container_port
  }

  health_check_grace_period_seconds = 30

  # Roll back automatically if the new tasks never become healthy
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  # Apply finishes only when the tasks are running and healthy
  wait_for_steady_state = true

  # The target group must be attached to the listener before the service registers targets
  depends_on = [aws_lb_listener_rule.this, aws_iam_role_policy_attachment.execution]

  tags = local.common_tags
}
