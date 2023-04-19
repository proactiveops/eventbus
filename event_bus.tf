resource "aws_cloudwatch_event_bus" "this" {
  name = local.namespace

  event_source_name = local.event_source_name

  tags = var.tags
}

resource "aws_cloudwatch_event_archive" "this" {
  name             = local.namespace_clean
  description      = "Event archive for all events flowing through the ${aws_cloudwatch_event_bus.this.name} bus"
  event_source_arn = aws_cloudwatch_event_bus.this.arn
}

resource "aws_cloudwatch_event_bus_policy" "this" {
  count = local.is_partner_source ? 0 : 1

  policy         = data.aws_iam_policy_document.event_bus.json
  event_bus_name = aws_cloudwatch_event_bus.this.name
}

resource "aws_cloudwatch_log_group" "this" {
  for_each = {
    for index, rule in var.cross_bus_rules : rule.name => rule.debug
    if rule.debug
  }
  name              = "/aws/events/${aws_cloudwatch_event_bus.this.name}/${each.key}"
  retention_in_days = 3
  tags              = var.tags
}

#Set the log group as a target for the Eventbridge rule
resource "aws_cloudwatch_event_target" "this" {
  for_each = {
    for index, rule in var.cross_bus_rules : rule.name => rule.debug
    if rule.debug
  }
  rule           = aws_cloudwatch_event_rule.targets[each.key].name
  arn            = aws_cloudwatch_log_group.this[each.key].arn
  event_bus_name = aws_cloudwatch_event_rule.targets[each.key].event_bus_name
}

data "aws_cloudwatch_event_source" "partner" {
  count = local.is_partner_source ? 1 : 0

  name_prefix = var.name
}

locals {
  event_source_name = local.is_partner_source ? data.aws_cloudwatch_event_source.partner[0].name : null
}
