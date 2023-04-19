data "aws_iam_policy_document" "event_bus" {
  statement {
    sid       = "iamManageBus"
    effect    = "Allow"
    actions   = ["events:*"]
    resources = [aws_cloudwatch_event_bus.this.arn]

    principals {
      type        = "AWS"
      identifiers = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }

  dynamic "statement" {
    # Hack to allow dynamic inclusion of the extra ARNs if they var is set.
    for_each = length(var.allow_put_events_arns) > 0 ? [1] : []

    content {
      sid       = "allowPutEventsExternal"
      effect    = "Allow"
      actions   = ["events:PutEvents"]
      resources = [aws_cloudwatch_event_bus.this.arn]

      principals {
        type        = "AWS"
        identifiers = ["*"]
      }

      condition {
        test     = "StringLike"
        variable = "aws:SourceArn"
        values   = var.allow_put_events_arns
      }
    }
  }

  override_policy_documents = var.bus_policy_docs
}
