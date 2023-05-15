# Define para aparecerem logs

resource "aws_cloudwatch_log_group" "devninja_worker_apache" {
  name = "/ecs/devninja_worker_apache"
  retention_in_days = 14
}

resource "aws_ecs_task_definition" "devninja_worker_apache" {
  family                   = "devninja_worker_apache"
  network_mode             = "bridge"
  cpu                      = "256"
  memory                   = "128"
  requires_compatibilities = ["EC2"]

  container_definitions = <<DEFINITION
  [
    {
      "name": "devninja_worker_apache",
      "image": "${aws_ecr_repository.devninja_ecr_1.repository_url}:main",
      "cpu": 256,
      "memory": 128,
      "essential": true,
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/devninja_worker_apache",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ]
  DEFINITION
}

resource "aws_ecs_service" "devninja_worker_apache" {
  name            = "devninja_worker_apache"
  cluster         = aws_ecs_cluster.devninja_worker.id
  task_definition = aws_ecs_task_definition.devninja_worker_apache.arn
  desired_count   = 1
  launch_type     = "EC2"
}