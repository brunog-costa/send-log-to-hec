resource "aws_s3_bucket" "sor_bucket" {
  bucket = "sor-${var.app_name}-${var.environment}"
  tags = merge(var.tags, {
    "AppName" : "${var.app_name}",
    "Environment" : "${var.environment}",
    "s3_bucket_type" : "private",
    "s3_data_retention" : "0",
    "s3_data_classification" : "${var.data_classification}"
  })
}

#Uses CMK becaus of data classification
resource "aws_s3_bucket_server_side_encryption_configuration" "sor_bucket_sse" {
  bucket = aws_s3_bucket.sor_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = module.glue_security_configuration.key_arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_intelligent_tiering_configuration" "sor_bucket-inteligent_tiering" {
  bucket = aws_s3_bucket.sor_bucket.id
  name   = "EntireBucket"

  tiering {
    access_tier = "DEEP_ARCHIVE_ACCESS"
    days        = 180
  }
  tiering {
    access_tier = "ARCHIVE_ACCESS"
    days        = 90
  }
}


resource "aws_s3_bucket_public_access_block" "sor_bucket_access_block" {
  bucket                  = aws_s3_bucket.sor_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "sor_bucket_policy" {
  bucket = aws_s3_bucket.sor_bucket.id
  policy = data.aws_iam_policy_document.sor_data_bucket_policy_document.json
}

data "aws_iam_policy_document" "sor_data_bucket_policy_document" {
  statement {
    sid    = "ForceSSLOnlyAccess"
    effect = "Deny"
    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = ["s3:*"]

    resources = [aws_s3_bucket.sor_bucket.arn, "${aws_s3_bucket.sor_bucket.arn}/*"]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_notification" "sor_bucket_notification" {
  bucket = aws_s3_bucket.sor_bucket.id

  queue {
    queue_arn     = aws_sqs_queue.queue.arn
    events        = ["s3:ObjectCreated:*"]
    filter_prefix = "Prefix/"
    filter_suffix = ".gz"
  }

  depends_on = [
    aws_lambda_permission.allow
  ]
}
