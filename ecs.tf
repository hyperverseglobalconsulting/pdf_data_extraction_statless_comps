resource "aws_ecs_cluster" "pdf_cluster" {
  name     = "pdf-cluster"
}

resource "aws_ecs_service" "pdf_service" {
  name             = "pdf-service"
  cluster          = aws_ecs_cluster.pdf_cluster.id
  task_definition  = aws_ecs_task_definition.pdf_task.arn
  desired_count    = 0
  launch_type      = "FARGATE"
  platform_version = "1.4.0"

  network_configuration {
    subnets          = aws_subnet.private_subnet[*].id
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = false
  }
}

resource "aws_ecs_task_definition" "pdf_task" {
  family                   = "pdf-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "pdf-to-doc"
      image     = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com/pdf-extractor:latest"
      essential = true
      environment = [
        {
          name  = "S3_BUCKET"
          value = data.aws_s3_bucket.pdf_storage.bucket
        },
        {
          name  = "OBJECT_KEY"
          value = "" # Will be overridden by the Lambda function
        },
        {
          name  = "SQS_QUEUE_URL"
          value = aws_sqs_queue.pdf_queue.id
        },
        {
          name  = "DLQ_QUEUE_URL"
          value = aws_sqs_queue.dlq.id
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs_log_group.name
          awslogs-region        = data.aws_region.current.name
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}
