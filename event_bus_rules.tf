resource "aws_cloudwatch_event_rule" "targets" {
  for_each = { for index, rule in var.cross_bus_rules : rule.name => rule }

  name = each.value.name

  event_bus_name = aws_cloudwatch_event_bus.this.name
  event_pattern  = each.value.pattern

  tags = var.tags
}

data "aws_iam_policy_document" "events_assume" {

  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }

  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "events_cross_account" {
  for_each = { for index, rule in var.cross_bus_rules : rule.name => rule }

  statement {
    effect = "Allow"

    actions = [
      "events:PutEvents"
    ]

    resources = [
      each.value.target_arn
    ]
  }
}

resource "aws_iam_policy" "events_cross_account" {
  for_each = { for index, rule in var.cross_bus_rules : rule.name => rule }

  name   = "events-cross-account-${each.value.name}-${var.tags.environment}"
  policy = data.aws_iam_policy_document.events_cross_account[each.key].json
}

resource "aws_iam_role_policy_attachment" "events_cross_account" {
  for_each = { for index, rule in var.cross_bus_rules : rule.name => rule }

  role       = aws_iam_role.events_cross_account[each.key].name
  policy_arn = aws_iam_policy.events_cross_account[each.key].arn
}

resource "aws_iam_role" "events_cross_account" {
  for_each = { for index, rule in var.cross_bus_rules : rule.name => rule }

  # CWE used as it's still used as the internal AWS namspace for eventbridge. Ensures unique role name.
  name_prefix        = "cwe-x-acct-"
  assume_role_policy = data.aws_iam_policy_document.events_assume.json
}

resource "aws_cloudwatch_event_target" "targets" {
  for_each = { for index, rule in var.cross_bus_rules : rule.name => rule }

  rule           = aws_cloudwatch_event_rule.targets[each.key].name
  event_bus_name = aws_cloudwatch_event_bus.this.name
  target_id      = each.value.name
  arn            = each.value.target_arn
  role_arn       = aws_iam_role.events_cross_account[each.key].arn

  dynamic "dead_letter_config" {
    for_each = each.value.dlq_arn != null ? [each.value.dlq_arn] : []
    content {
      arn = dead_letter_config.value
    }
  }
}
