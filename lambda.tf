/* 
  Send AWS Acccount data to SIEM 
*/
resource "aws_lambda_function" "snow-data-lambda-function" {
  function_name = "send-${var.environment}-aws-accounts-${var.app_name}-to-siem"
  description   = var.lambda_description
  role          = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/iamsr/send-snow-data-to-siem-iam-role"
  handler       = var.lambda_handler
  runtime       = var.lambda_runtime
  filename      = "${path.module}/resources/aws-accounts/lambda_function.zip"
  memory_size   = var.lambda_memory_size
  kms_key_arn   = module.glue_security_configuration.key_arn
  tags = merge(var.tags, {
    "AppName" : "${var.app_name}",
    "Environment" : "${var.environment}"
  })
  timeout = var.lambda_timeout

  vpc_config {
    security_group_ids = [var.lambda_vpc_config_security_group]
    subnet_ids         = var.lambda_vpc_config_subnet_id
  }

  environment {
    variables = {
      SPLUNK_HEC_TOKEN = "${var.environment}-aws-accounts-${var.app_name}-lambda-secret"
      SPLUNK_HEC_URL   = "${var.lambda_env_splunk_hec_url}"
    }
  }

  depends_on = [
    module.iamsr_module
  ]
}

resource "aws_lambda_permission" "allow_sqs" {
  statement_id  = "AllowExecutionFromSQS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.snow-data-lambda-function.function_name
  principal     = "sqs.amazonaws.com"
  source_arn    = aws_sqs_queue.snow-data-aws-accounts-queue.arn
}

resource "aws_lambda_event_source_mapping" "snow-data-lambda-trigger" {
  event_source_arn = aws_sqs_queue.snow-data-aws-accounts-queue.arn
  enabled          = true
  function_name    = aws_lambda_function.snow-data-lambda-function.function_name
  batch_size       = 10
}

resource "aws_cloudwatch_log_group" "snow-data-lambda-function-log-group" {
  name              = "/aws/lambda/send-${var.environment}-aws-accounts-${var.app_name}-to-siem"
  retention_in_days = 30
  depends_on = [
    aws_lambda_function.snow-data-lambda-function
  ]
  tags = merge(var.tags, {
    "AppName" : "${var.app_name}",
    "Environment" : "${var.environment}"
  })
}

/* 
  Send CMDB Servers data to SIEM 
*/
resource "aws_lambda_function" "cmdb-servers-snow-data-lambda-function" {
  function_name = "send-${var.environment}-cmdb-servers-${var.app_name}-to-siem"
  description   = var.lambda_description
  role          = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/iamsr/send-snow-data-to-siem-iam-role"
  handler       = var.lambda_handler
  runtime       = var.lambda_runtime
  filename      = "${path.module}/resources/cmdb-servers/lambda_function.zip"
  memory_size   = var.lambda_memory_size
  kms_key_arn   = module.glue_security_configuration.key_arn
  tags = merge(var.tags, {
    "AppName" : "${var.app_name}",
    "Environment" : "${var.environment}"
  })
  timeout = var.lambda_timeout

  vpc_config {
    security_group_ids = [var.lambda_vpc_config_security_group]
    subnet_ids         = var.lambda_vpc_config_subnet_id
  }

  environment {
    variables = {
      SPLUNK_HEC_TOKEN = "${var.environment}-cmdb-servers-${var.app_name}-lambda-secret"
      SPLUNK_HEC_URL   = "${var.lambda_env_splunk_hec_url}"
    }
  }

  depends_on = [
    module.iamsr_module
  ]
}

resource "aws_lambda_permission" "cmdb_servers_allow_sqs" {
  statement_id  = "AllowExecutionFromSQS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cmdb-servers-snow-data-lambda-function.function_name
  principal     = "sqs.amazonaws.com"
  source_arn    = aws_sqs_queue.snow-data-cmdb-servers-queue.arn
}

resource "aws_lambda_event_source_mapping" "snow-data-cmdb-servers-lambda-trigger" {
  event_source_arn = aws_sqs_queue.snow-data-cmdb-servers-queue.arn
  enabled          = true
  function_name    = aws_lambda_function.cmdb-servers-snow-data-lambda-function.function_name
  batch_size       = 10
}

resource "aws_cloudwatch_log_group" "cmdb_servers_snow-data-lambda-function-log-group" {
  name              = "/aws/lambda/send-${var.environment}-cmdb-servers-${var.app_name}-to-siem"
  retention_in_days = 30
  depends_on = [
    aws_lambda_function.cmdb-servers-snow-data-lambda-function
  ]
  tags = merge(var.tags, {
    "AppName" : "${var.app_name}",
    "Environment" : "${var.environment}"
  })
}

/* 
  Send CMDB DB Instance  data to SIEM 
*/
resource "aws_lambda_function" "cmdb-instances-db-snow-data-lambda-function" {
  function_name = "send-${var.environment}-cmdb-db-instances-${var.app_name}-to-siem"
  description   = var.lambda_description
  role          = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/iamsr/send-snow-data-to-siem-iam-role"
  handler       = var.lambda_handler
  runtime       = var.lambda_runtime
  filename      = "${path.module}/resources/cmdb-db-instances/lambda_function.zip"
  memory_size   = var.lambda_memory_size
  kms_key_arn   = module.glue_security_configuration.key_arn
  tags = merge(var.tags, {
    "AppName" : "${var.app_name}",
    "Environment" : "${var.environment}"
  })
  timeout = var.lambda_timeout

  vpc_config {
    security_group_ids = [var.lambda_vpc_config_security_group]
    subnet_ids         = var.lambda_vpc_config_subnet_id
  }

  environment {
    variables = {
      SPLUNK_HEC_TOKEN = "${var.environment}-cmdb-servers-${var.app_name}-lambda-secret"
      SPLUNK_HEC_URL   = "${var.lambda_env_splunk_hec_url}"
    }
  }

  depends_on = [
    module.iamsr_module
  ]
}

resource "aws_lambda_permission" "cmdb_instances_db_allow_sqs" {
  statement_id  = "AllowExecutionFromSQS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cmdb-instances-db-snow-data-lambda-function.function_name
  principal     = "sqs.amazonaws.com"
  source_arn    = aws_sqs_queue.snow-data-cmdb-db-instances-queue.arn
}

resource "aws_lambda_event_source_mapping" "snow-data-cmdb-db-instances-lambda-trigger" {
  event_source_arn = aws_sqs_queue.snow-data-cmdb-db-instances-queue.arn
  enabled          = true
  function_name    = aws_lambda_function.cmdb-instances-db-snow-data-lambda-function.function_name
  batch_size       = 10
}

resource "aws_cloudwatch_log_group" "cmdb_db_instance_snow-data-lambda-function-log-group" {
  name              = "/aws/lambda/send-${var.environment}-cmdb-db-instances-${var.app_name}-to-siem"
  retention_in_days = 30
  depends_on = [
    aws_lambda_function.cmdb-instances-db-snow-data-lambda-function
  ]
  tags = merge(var.tags, {
    "AppName" : "${var.app_name}",
    "Environment" : "${var.environment}"
  })
}
