/* 
    Common DLQ 
*/
resource "aws_sqs_queue" "snow-data-dead-letter-queue" {
  name                              = "${var.environment}-${var.app_name}-dead-letter-queue"
  kms_master_key_id                 = module.glue_security_configuration.key_arn
  kms_data_key_reuse_period_seconds = 3600
  delay_seconds                     = 0
  message_retention_seconds         = 345600 #4 days
  visibility_timeout_seconds        = 900    #15 minutes
  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue",
    sourceQueueArns   = [
      "arn:aws:sqs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${var.environment}-aws-accounts-${var.app_name}-queue",
      "arn:aws:sqs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${var.environment}-cmdb-servers-${var.app_name}-queue", 
      "arn:aws:sqs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${var.environment}-cmdb-db-instances-${var.app_name}-queue"]
  }) 
  tags = merge(var.tags, {
    "AppName" : "${var.app_name}",
    "Environment" : "${var.environment}"
  })
}

/* 
  Send AWS Acccount data to SIEM 
*/

resource "aws_sqs_queue" "snow-data-aws-accounts-queue" {
  name                              = "${var.environment}-aws-accounts-${var.app_name}-queue"
  kms_master_key_id                 = module.glue_security_configuration.key_arn
  kms_data_key_reuse_period_seconds = 3600
  delay_seconds                     = 0
  message_retention_seconds         = 345600 #4 days
  visibility_timeout_seconds        = 900    #15 minutes
  #policy                            = data.aws_iam_policy_document.snow-data-aws-accounts-queue-policy-aws_iam_policy_document.json
  redrive_policy = jsonencode({
    deadLetterTargetArn = "${aws_sqs_queue.snow-data-dead-letter-queue.arn}"
    maxReceiveCount     = 5
  })


  tags = merge(var.tags, {
    "AppName" : "${var.app_name}",
    "Environment" : "${var.environment}"
  })
}


resource "aws_sqs_queue_policy" "snow-data-aws-accounts-queue-policy" {
  queue_url = aws_sqs_queue.snow-data-aws-accounts-queue.id
  policy    = data.aws_iam_policy_document.snow-data-aws-accounts-queue-policy.json
}

/* 
  Send CMDB Servers data to SIEM
*/
resource "aws_sqs_queue" "snow-data-cmdb-servers-queue" {
  name                              = "${var.environment}-cmdb-servers-${var.app_name}-queue"
  kms_master_key_id                 = module.glue_security_configuration.key_arn
  kms_data_key_reuse_period_seconds = 3600
  delay_seconds                     = 0
  message_retention_seconds         = 345600 #4 days
  visibility_timeout_seconds        = 900    #15 minutes
  #policy                            = data.aws_iam_policy_document.snow-data-cmdb-servers-queue-policy-aws_iam_policy_document.json
  redrive_policy = jsonencode({
    deadLetterTargetArn = "${aws_sqs_queue.snow-data-dead-letter-queue.arn}"
    maxReceiveCount     = 5
  })


  tags = merge(var.tags, {
    "AppName" : "${var.app_name}",
    "Environment" : "${var.environment}"
  })
}

resource "aws_sqs_queue_policy" "snow-data-cmdb-servers-queue-policy" {
  queue_url = aws_sqs_queue.snow-data-cmdb-servers-queue.id
  policy    = data.aws_iam_policy_document.snow-data-cmdb-servers-queue-policy.json
}

/* 
  Send CMDB DB Instance  data to SIEM 
*/
resource "aws_sqs_queue" "snow-data-cmdb-db-instances-queue" {
  name                              = "${var.environment}-cmdb-db-instances-${var.app_name}-queue"
  kms_master_key_id                 = module.glue_security_configuration.key_arn
  kms_data_key_reuse_period_seconds = 3600
  delay_seconds                     = 0
  message_retention_seconds         = 345600 #4 days
  visibility_timeout_seconds        = 900    #15 minutes
  #policy                            = data.aws_iam_policy_document.snow-data-cmdb-db-instances-queue-policy-aws_iam_policy_document.json
  redrive_policy = jsonencode({
    deadLetterTargetArn = "${aws_sqs_queue.snow-data-dead-letter-queue.arn}"
    maxReceiveCount     = 5
  })


  tags = merge(var.tags, {
    "AppName" : "${var.app_name}",
    "Environment" : "${var.environment}"
  })
}

resource "aws_sqs_queue_policy" "snow-data-cmdb-db-instances-queue-policy" {
  queue_url = aws_sqs_queue.snow-data-cmdb-db-instances-queue.id
  policy    = data.aws_iam_policy_document.snow-data-cmdb-db-instances-queue-policy.json
}

#SQS CMDB Instances Queue
data "aws_iam_policy_document" "snow-data-cmdb-db-instances-queue-policy" {
  statement {
    sid    = "AllowRootAccount"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }

    actions   = ["sqs:*"]
    resources = [aws_sqs_queue.snow-data-cmdb-db-instances-queue.arn]
  }
  statement {
    sid    = "AllowS3Notification"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com", "lambda.amazonaws.com"]
    }

    actions   = ["sqs:SendMessage", "sqs:ReceiveMessage"]
    resources = [aws_sqs_queue.snow-data-cmdb-db-instances-queue.arn]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = ["${data.aws_caller_identity.current.account_id}"]
    }
  }
}
