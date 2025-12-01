resource "aws_kms_key" "queue" {
  description             = "Encryption key for ${var.project} ${var.environment}"
  deletion_window_in_days = var.key_recovery_period
  enable_key_rotation     = true
  policy = jsonencode(yamldecode(templatefile("${path.module}/templates/queue-key-policy.yaml.tftpl", {
    account_id : data.aws_caller_identity.identity.account_id,
    partition : data.aws_partition.current.partition
  })))

  tags = var.tags
}

resource "aws_kms_alias" "queue" {
  name          = "alias/${var.project}/${var.environment}"
  target_key_id = aws_kms_key.queue.id
}

module "sqs" {
  source  = "terraform-aws-modules/sqs/aws"
  version = "~> 5.0"

  name = "${local.prefix}-queue"

  kms_master_key_id                 = aws_kms_key.queue.id
  kms_data_key_reuse_period_seconds = 3600
  create_dlq                        = true

  # Convert retention from days to seconds,
  message_retention_seconds = var.message_expiration * 86400

  tags = var.tags
}

module "s3" {
  source  = "boldlink/s3/aws"
  version = "~> 2.6"

  bucket            = "${local.prefix}-exports"
  versioning_status = "Enabled"

  sse_bucket_key_enabled = true
  sse_kms_master_key_arn = aws_kms_key.queue.arn
  sse_sse_algorithm      = "aws:kms"

  bucket_policy = jsonencode(yamldecode(templatefile("${path.module}/templates/bucket-policy.yaml.tftpl", {
    bucket_arn : module.s3.arn
  })))

  s3_logging = {
    target_bucket = var.logging_bucket
    target_prefix = "/"
  }

  lifecycle_configuration = [
    {
      id     = "exports"
      status = "Enabled"

      abort_incomplete_multipart_upload_days = 7

      # Apply this configuration to all objects in the bucket.
      filter = { prefix = "" }

      # Expire non-current versions.
      noncurrent_version_expiration = [
        {
          days = 30
        }
      ]

      # Expire current versions. Objects will be deleted after the expiration,
      # based on the non-current expiration.
      expiration = [
        {
          days = var.export_expiration
        }
      ]
    }
  ]

  tags = var.tags
}

resource "aws_s3_bucket_object_lock_configuration" "export" {
  for_each = var.export_lock_mode != "DISABLED" ? toset(["this"]) : toset([])

  bucket = module.s3.bucket

  rule {
    default_retention {
      mode  = var.export_lock_mode
      days  = var.export_lock_period == "days" ? var.export_lock_age : null
      years = var.export_lock_period == "years" ? var.export_lock_age : null
    }
  }
}
