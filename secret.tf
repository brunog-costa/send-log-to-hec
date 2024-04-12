/* AWS Accounts Secret */
resource "aws_secretsmanager_secret" "splunk_aws_accounts_token_secret" {
  name        = "${var.environment}-aws-accounts-${var.app_name}-lambda-secret"
  description = "Splunk Token for AWS accounts"
  kms_key_id  = module.glue_security_configuration.key_arn
  tags = merge(var.tags, {
    "AppName" : "${var.app_name}",
    "Environment" : "${var.environment}"
  })
}

/*
resource "aws_secretsmanager_secret_version" "splunk_token_secret_value" {
  secret_id     = aws_secretsmanager_secret.splunk_token_secret.id
  secret_string = var.splunk_token
}
*/
