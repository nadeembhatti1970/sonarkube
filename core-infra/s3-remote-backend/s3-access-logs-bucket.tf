# ---------------------------------------------------------------------------
# Dedicated destination bucket for S3 server access logs.
#
# Kept separate from the state bucket so that (a) log delivery cannot be used
# to overwrite or enumerate state and (b) the state bucket can retain a strict
# deny-by-default bucket policy without an exception for the logging service.
# ---------------------------------------------------------------------------
#checkov:skip=CKV_AWS_18:This bucket is itself the access-log destination; logging it into itself would recurse and add cost.
#checkov:skip=CKV_AWS_144:State and access logs are deliberately single-region; recovery uses versioning plus the KMS key, not cross-region replication.
#checkov:skip=CKV2_AWS_62:No workflow depends on S3 event notifications for access logs.
resource "aws_s3_bucket" "state_access_logs" {
  bucket        = var.state_access_logs_bucket_name
  force_destroy = false

  tags = merge(local.common_tags, {
    Name    = var.state_access_logs_bucket_name
    Purpose = "s3-server-access-logs"
  })
}

resource "aws_s3_bucket_ownership_controls" "state_access_logs" {
  bucket = aws_s3_bucket.state_access_logs.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "state_access_logs" {
  bucket = aws_s3_bucket.state_access_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state_access_logs" {
  bucket = aws_s3_bucket.state_access_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.tfstate.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_versioning" "state_access_logs" {
  bucket = aws_s3_bucket.state_access_logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "state_access_logs" {
  bucket = aws_s3_bucket.state_access_logs.id

  rule {
    id     = "expire-access-logs"
    status = "Enabled"

    filter {}

    expiration {
      days = 365
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_s3_bucket_policy" "state_access_logs" {
  bucket = aws_s3_bucket.state_access_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyInsecureTransport"
        Effect = "Deny"
        Principal = {
          AWS = "*"
        }
        Action   = "s3:*"
        Resource = [aws_s3_bucket.state_access_logs.arn, "${aws_s3_bucket.state_access_logs.arn}/*"]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
      {
        Sid    = "AllowAccessLogDelivery"
        Effect = "Allow"
        Principal = {
          Service = "logging.s3.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.state_access_logs.arn}/*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}
