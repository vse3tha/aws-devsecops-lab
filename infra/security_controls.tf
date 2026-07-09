resource "aws_s3_bucket" "config_logs" {
  count  = var.enable_aws_config ? 1 : 0
  bucket = "${var.name_prefix}-aws-config-${data.aws_caller_identity.current.account_id}-${var.aws_region}"
}

resource "aws_s3_bucket_public_access_block" "config_logs" {
  count  = var.enable_aws_config ? 1 : 0
  bucket = aws_s3_bucket.config_logs[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_iam_role" "config" {
  count = var.enable_aws_config ? 1 : 0
  name  = "${var.name_prefix}-aws-config-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "config.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "config_managed" {
  count      = var.enable_aws_config ? 1 : 0
  role       = aws_iam_role.config[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

resource "aws_iam_role_policy" "config_s3" {
  count = var.enable_aws_config ? 1 : 0
  name  = "${var.name_prefix}-aws-config-s3-policy"
  role  = aws_iam_role.config[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.config_logs[0].arn
      },
      {
        Effect   = "Allow"
        Action   = "s3:ListBucket"
        Resource = aws_s3_bucket.config_logs[0].arn
      },
      {
        Effect   = "Allow"
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.config_logs[0].arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/Config/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

resource "aws_config_configuration_recorder" "main" {
  count    = var.enable_aws_config ? 1 : 0
  name     = "${var.name_prefix}-recorder"
  role_arn = aws_iam_role.config[0].arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }

  depends_on = [aws_iam_role_policy_attachment.config_managed]
}

resource "aws_config_delivery_channel" "main" {
  count          = var.enable_aws_config ? 1 : 0
  name           = "${var.name_prefix}-delivery-channel"
  s3_bucket_name = aws_s3_bucket.config_logs[0].bucket

  depends_on = [aws_config_configuration_recorder.main]
}

resource "aws_config_configuration_recorder_status" "main" {
  count      = var.enable_aws_config ? 1 : 0
  name       = aws_config_configuration_recorder.main[0].name
  is_enabled = true

  depends_on = [aws_config_delivery_channel.main]
}

resource "aws_config_config_rule" "s3_public_read" {
  count = var.enable_aws_config ? 1 : 0
  name  = "${var.name_prefix}-s3-public-read-prohibited"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_PUBLIC_READ_PROHIBITED"
  }

  depends_on = [aws_config_configuration_recorder_status.main]
}

resource "aws_config_config_rule" "restricted_ssh" {
  count = var.enable_aws_config ? 1 : 0
  name  = "${var.name_prefix}-restricted-ssh"

  source {
    owner             = "AWS"
    source_identifier = "INCOMING_SSH_DISABLED"
  }

  depends_on = [aws_config_configuration_recorder_status.main]
}

resource "aws_guardduty_detector" "main" {
  count  = var.enable_guardduty ? 1 : 0
  enable = true
}
