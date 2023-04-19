resource "aws_schemas_discoverer" "this" {
  count = var.enable_schema_discovery_registry ? 1 : 0

  source_arn  = aws_cloudwatch_event_bus.this.arn
  description = "Auto discover event schemas for ${local.namespace}."

  tags = var.tags
}
