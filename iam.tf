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
