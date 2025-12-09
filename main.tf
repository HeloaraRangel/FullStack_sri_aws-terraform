provider "aws" {
  region = "us-east-1"
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_ecs_cluster" "cluster" {
  name = "videolocadora-cluster"
}

resource "aws_security_group" "sg" {
  name   = "videolocadora-sg"
  vpc_id = data.aws_vpc.default.id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 5173
    to_port     = 5173
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_ecs_task_definition" "task" {
  family                   = "videolocadora-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "1024"
  memory                   = "2048"

  container_definitions = jsonencode([
    {
      name      = "postgres"
      image     = "postgres:16"
      essential = true
      portMappings = [
        {
          containerPort = 5432
        }
      ]
      environment = [
        { name = "POSTGRES_DB", value = "videoLocadora" },
        { name = "POSTGRES_USER", value = "postgres" },
        { name = "POSTGRES_PASSWORD", value = "122760" }
      ]
    },
    {
      name      = "spring"
      image     = "heloara/spring-videolocadora:latest"
      essential = true
      portMappings = [
        {
          containerPort = 8080
        }
      ]
      environment = [
        { name = "DB_HOST", value = "localhost" },
        { name = "DB_PORT", value = "5432" },
        { name = "DB_NAME", value = "videoLocadora" },
        { name = "DB_USER", value = "postgres" },
        { name = "DB_PASSWORD", value = "122760" }
      ]
    },
    {
      name      = "vue"
      image     = "heloara/vue-videolocadora:latest"
      essential = true
      portMappings = [
        {
          containerPort = 5173
        }
      ]
      
    }
  ])
}

resource "aws_ecs_service" "service" {
  name            = "videolocadora-service"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.default.ids
    security_groups  = [aws_security_group.sg.id]
    assign_public_ip = true
  }
}
