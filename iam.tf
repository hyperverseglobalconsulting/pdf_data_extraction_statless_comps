resource "aws_iam_role" "lambda_role" {
  name = "lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "ecs:RunTask",
          "iam:PassRole",
          "ec2:CreateNetworkInterface", # Required for VPC
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface",
          "ec2:AssignPrivateIpAddresses",
          "ec2:UnassignPrivateIpAddresses"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = "s3:GetObject"
        Resource = "${data.aws_s3_bucket.pdf_storage.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = "logs:*"
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecs:RunTask",
          "ecs:DescribeTasks",
          "ecs:ListTasks"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach the AWSLambdaVPCAccessExecutionRole policy to the Lambda role
resource "aws_iam_role_policy_attachment" "lambda_vpc_access" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role" "ecs_task_role" {
  name = "ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "ecs_task_policy" {
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
          "s3:PutObject"
        ]
        Effect = "Allow"
        Resource = [
          "${data.aws_s3_bucket.pdf_storage.arn}",
          "${data.aws_s3_bucket.pdf_storage.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:GetAuthorizationToken",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:CreateLogGroup"
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/ecs/pdf-task:*"
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = "arn:aws:sqs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:pdf-dlq"
      }
    ]
  })
}

# S3 Bucket Policy
data "aws_iam_policy_document" "bucket_policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.website.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.oai.iam_arn]
    }
  }

  statement {
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.website.arn}/upload/*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:authType"
      values   = ["AWS4-HMAC-SHA256"]
    }
  }

  # Add explicit public read for static assets (if needed)
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.website.arn}/static/*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}

resource "aws_iam_role" "lambda_exec" {
  name = "lambda-presigned-url-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_policy" "terraform_deploy" {
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      # Add explicit IAM role creation permission
      {
        Sid    = "IAMRoleCreation",
        Effect = "Allow",
        Action = [
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:TagRole"
        ],
        Resource = "arn:aws:iam::*:role/lambda-presigned-url-role*"
      }
    ]
  })
}

# Basic Lambda execution policy
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}


# Basic Lambda execution policy
resource "aws_iam_role_policy_attachment" "lambda_create_role" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.terraform_deploy.arn
}

# S3-specific permissions for presigned URL operations
resource "aws_iam_role_policy" "s3_access" {
  name = "s3-presigned-url-access"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
        ]
        Resource = "${aws_s3_bucket.website.arn}/upload/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = "${aws_s3_bucket.website.arn}/processed/*"
      },
      {
        Effect = "Allow"
        Action = "s3:ListBucket"
        Resource = [
          "${aws_s3_bucket.website.arn}/upload",
          "${aws_s3_bucket.website.arn}/processed"
        ]
      }
    ]
  })
}

# iam.tf
resource "aws_iam_role" "api_gateway_cloudwatch_role" {
  name = "api-gateway-cloudwatch-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "api_gateway_cloudwatch_policy" {
  name = "api-gateway-cloudwatch-policy"
  role = aws_iam_role.api_gateway_cloudwatch_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "execute-api:Invoke",
          "execute-api:ManageConnections"
        ]
        Effect   = "Allow"
        Resource = "${aws_apigatewayv2_api.presigned_url_api.execution_arn}/*"
      }
    ]
  })
}

#data "aws_iam_policy_document" "web_hosting" {
#  statement {
#    actions   = ["s3:GetObject"]
#    resources = ["${aws_s3_bucket.web_hosting.arn}/*"]
#
#    principals {
#      type        = "AWS"
#      identifiers = [aws_cloudfront_origin_access_identity.oai.iam_arn]
#    }
#  }
#
#  statement {
#    actions   = ["s3:ListBucket"]
#    resources = [aws_s3_bucket.web_hosting.arn]
#
#    principals {
#      type        = "AWS"
#      identifiers = [aws_cloudfront_origin_access_identity.oai.iam_arn]
#    }
#  }
#}
#
#resource "aws_iam_role_policy" "lambda_s3_policy" {
#  # ...
#  policy = jsonencode({
#    Version = "2012-10-17",
#    Statement = [{
#      Effect   = "Allow",
#      Action   = ["s3:PutObject"],
#      Resource = "${aws_s3_bucket.uploads.arn}/*"
#    }]
#  })
#}
#
#resource "aws_s3_bucket" "uploads" {
#  # ...
#  cors_rule {
#    allowed_origins = ["https://pdf2docx.vizeet.me"]
#    allowed_methods = ["PUT"]
#    allowed_headers = ["*"]
#  }
#}
