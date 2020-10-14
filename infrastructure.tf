
locals {
  layer_filename    = "etl_layer.zip"
  function_filename = "etl_function.zip"
}

# CloudWatch log group
resource "aws_cloudwatch_log_group" "etl_log_group" {
  # name = "/aws/lambda/etl/"
  name              = "/aws/lambda/${aws_lambda_function.etl_function.function_name}"
  retention_in_days = 14
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

# Send SNS notification on failure
resource "aws_lambda_function_event_invoke_config" "etl_function_event_config" {
  function_name = aws_lambda_function.etl_function.function_name

  destination_config {
    on_failure {
      destination = aws_sns_topic.etl_failure_topic.id
    }
  }
}

# Lambda triggers
resource "aws_cloudwatch_event_rule" "etl_rule_every_day_at_1900" {
    name = "every-day-1900"
    description = "Fires every day at 7 pm"
    schedule_expression = "cron(0 19 * * ? *)"
}

resource "aws_cloudwatch_event_target" "check_foo_every_five_minutes" {
    target_id = "EtlLambdaTarget"
    rule = aws_cloudwatch_event_rule.etl_rule_every_day_at_1900.name
    arn = aws_lambda_function.etl_function.arn
}

resource "aws_lambda_permission" "allow_cloudwatch_to_call_etl_function" {
    statement_id = "AllowEtlLambdaFunctionExecutionFromCloudWatch"
    action = "lambda:InvokeFunction"
    function_name = aws_lambda_function.etl_function.function_name
    principal = "events.amazonaws.com"
    source_arn = aws_cloudwatch_event_rule.etl_rule_every_day_at_1900.arn
}