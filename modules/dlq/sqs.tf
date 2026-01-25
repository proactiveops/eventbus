# Copyright 2023 - 2026 Dave Hall, https://proactiveops.io, MIT License

resource "aws_sqs_queue" "dlq" {
  name = "${var.queue_name}-dlq"

  message_retention_seconds = 86400
  delay_seconds             = 0
  receive_wait_time_seconds = 0
  max_message_size          = 262144

  kms_master_key_id = var.kms_key_id

  tags = var.tags
}

data "aws_iam_policy_document" "dlq" {

  statement {
    sid       = "EventBridgeToSQS"
    effect    = "Allow"
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.dlq.arn]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
  }

  dynamic "statement" {
    for_each = var.kms_key_id == null ? [1] : []
    content {
      sid    = "events-policy"
      effect = "Allow"
      actions = [
        "kms:Decrypt",
        "kms:GenerateDataKey"
      ]
      principals {
        type        = "Service"
        identifiers = ["events.amazonaws.com"]
      }
      resources = [
        var.kms_key_id
      ]
    }
  }
}

resource "aws_sqs_queue_policy" "dlq" {
  queue_url = aws_sqs_queue.dlq.id
  policy    = data.aws_iam_policy_document.dlq.json
}
