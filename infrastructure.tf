
locals {
  layer_filename    = "etl_layer.zip"
  function_filename = "etl_function.zip"
}

# VPC config
resource "aws_vpc" "etl_vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "etl-vpc"
  }
}

resource "aws_internet_gateway" "etl_igw" {
  vpc_id = aws_vpc.etl_vpc.id

  tags = {
    Name = "etl-igw"
  }
}

data "aws_security_group" "etl_default_sg" {
  vpc_id = aws_vpc.etl_vpc.id
  name   = "default"
}

# Subnets
data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "etl_public_a" {
  vpc_id            = aws_vpc.etl_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "etl-public-a"
  }
}

resource "aws_subnet" "etl_public_b" {
  vpc_id            = aws_vpc.etl_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "etl-public-b"
  }
}

resource "aws_subnet" "etl_private_a" {
  vpc_id            = aws_vpc.etl_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "etl-private-a"
  }
}

resource "aws_subnet" "etl_private_b" {
  vpc_id            = aws_vpc.etl_vpc.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "etl-private-b"
  }
}

# NAT 
resource "aws_eip" "etl_nat_gw" {
  vpc = true
}

resource "aws_nat_gateway" "etl_nat_gw" {
  allocation_id = aws_eip.etl_nat_gw.id
  subnet_id     = aws_subnet.etl_public_a.id
}

# VPC Route tables
resource "aws_route_table" "etl_private_route_table" {
  vpc_id = aws_vpc.etl_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.etl_nat_gw.id
  }

  tags = {
    Name = "etl-private-route-table"
  }
}

resource "aws_route_table_association" "etl_private_subnet_a_route_table" {
  subnet_id      = aws_subnet.etl_private_a.id
  route_table_id = aws_route_table.etl_private_route_table.id
}

resource "aws_route_table_association" "etl_private_subnet_b_route_table" {
  subnet_id      = aws_subnet.etl_private_b.id
  route_table_id = aws_route_table.etl_private_route_table.id
}

resource "aws_route_table" "etl_public_route_table" {
  vpc_id = aws_vpc.etl_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.etl_igw.id
  }

  tags = {
    Name = "etl-public-route-table"
  }
}

resource "aws_route_table_association" "etl_public_subnet_a_route_table" {
  subnet_id      = aws_subnet.etl_public_a.id
  route_table_id = aws_route_table.etl_public_route_table.id
}

resource "aws_route_table_association" "etl_public_subnet_b_route_table" {
  subnet_id      = aws_subnet.etl_public_b.id
  route_table_id = aws_route_table.etl_public_route_table.id
}

# RDS
resource "aws_db_subnet_group" "etl_db_subnet_group" {
  name       = "etl-db-subnet-group"
  subnet_ids = [aws_subnet.etl_private_a.id, aws_subnet.etl_private_b.id]

  tags = {
    Name = "ETL DB Subnet Group"
  }
}

resource "aws_db_instance" "etl_db" {
  identifier              = "etl-db"
  engine                  = "postgres"
  engine_version          = "12.3"
  instance_class          = "db.t2.micro"
  allocated_storage       = 20
  storage_type            = "gp2"
  backup_retention_period = 0
  db_subnet_group_name    = aws_db_subnet_group.etl_db_subnet_group.name

  name                 = "postgres"
  username             = var.rds-username
  password             = var.rds-password
  parameter_group_name = "default.postgres12"

  publicly_accessible = false
}

# CloudWatch log group
resource "aws_cloudwatch_log_group" "etl_log_group" {
  name = "/aws/lambda/etl/"
  # name              = "/aws/lambda/etl/${aws_lambda_function.etl_function.function_name}"
  retention_in_days = 14
}

# Lambda role
data "aws_iam_policy_document" "etl_lambda_assume_role_policy_document" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "iam_role_for_etl_lambda" {
  name               = "etl-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.etl_lambda_assume_role_policy_document.json
}

# permissions policies for the Lambda role
data "aws_iam_policy_document" "etl_lambda_role_policy_document" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:CreateLogGroup",
    ]
    resources = [aws_cloudwatch_log_group.etl_log_group.arn]
  }

  statement {
    effect    = "Allow"
    actions   = ["logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.etl_log_group.arn}:*"]
  }

  statement {
    effect  = "Allow"
    actions = ["sns:Publish"]
    resources = [
      "arn:aws:sns:us-east-1:074353190386:etl-failure-topic",
      "arn:aws:sns:us-east-1:074353190386:etl-success-topic",
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "ec2:CreateNetworkInterface",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DeleteNetworkInterface"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "iam_role_policy_for_etl_lambda" {
  name   = "etl-lambda-policy"
  policy = data.aws_iam_policy_document.etl_lambda_role_policy_document.json
  role   = aws_iam_role.iam_role_for_etl_lambda.id
}

# SNS
# Terraform does not support email subscriptions to SNS topics, so 
# they have to be created manually and maintained outside of terraform
resource "aws_sns_topic" "etl_failure_topic" {
  name = "etl-failure-topic"
}

resource "aws_sns_topic" "etl_success_topic" {
  name = "etl-success-topic"
}

# Lambda layer
resource "aws_lambda_layer_version" "etl_layer" {
  layer_name          = "etl-layer"
  filename            = local.layer_filename
  source_code_hash    = filebase64sha256(local.layer_filename)
  compatible_runtimes = ["python3.8"]
  # depends_on          = [null_resource.provision_lambda_deployment_package]
}

# Lambda Function
resource "aws_lambda_function" "etl_function" {
  function_name    = "etl-function"
  role             = aws_iam_role.iam_role_for_etl_lambda.arn
  handler          = "main.handler"
  filename         = local.function_filename
  source_code_hash = filebase64sha256(local.function_filename)
  runtime          = "python3.8"
  timeout          = 30
  layers           = [aws_lambda_layer_version.etl_layer.arn]
  # depends_on       = [null_resource.provision_lambda_deployment_package]

  environment {
    variables = {
      POSTGRES_DB           = aws_db_instance.etl_db.name,
      POSTGRES_HOST         = aws_db_instance.etl_db.address,
      POSTGRES_USER         = aws_db_instance.etl_db.username,
      POSTGRES_PASSWORD     = aws_db_instance.etl_db.password,
      POSTGRES_PORT         = aws_db_instance.etl_db.port,
      SUCCESS_SNS_TOPIC_ARN = aws_sns_topic.etl_success_topic.arn,
    }
  }

  vpc_config {
    subnet_ids         = [aws_subnet.etl_private_a.id, aws_subnet.etl_private_b.id]
    security_group_ids = [data.aws_security_group.etl_default_sg.id]
  }
}

resource "aws_lambda_function_event_invoke_config" "etl_function_event_config" {
  function_name = aws_lambda_function.etl_function.function_name

  destination_config {
    on_failure {
      destination = aws_sns_topic.etl_failure_topic.id
    }
  }
}