data "aws_iam_policy_document" "kms" {
  statement {
    sid    = "IAMAdmin"
    effect = "Allow"
    actions = [
      "kms:*"
    ]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = [data.aws_caller_identity.current.account_id]
    }
  }

  statement {
    sid    = "EventBridgeToSQS"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey"
    ]
    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
  }
}

resource "aws_kms_key" "this" {
  count       = local.kms_count
  description = "KMS key for ${var.queue_name} DLQ"
  policy      = data.aws_iam_policy_document.kms.json

  enable_key_rotation = true

  tags = var.tags
}

resource "aws_kms_alias" "this" {
  count         = local.kms_count
  name          = "alias/sqs-${var.queue_name}"
  target_key_id = aws_kms_key.this[0].arn
}
