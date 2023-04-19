
output "bus" {
  value       = aws_cloudwatch_event_bus.this
  description = "The bus resource created by this module."
}

output "cross_bus_rules_arns" {
  value       = { for name, rule in aws_cloudwatch_event_rule.targets : name => rule.arn }
  description = "ARNs of cross bus rules created for this bus."
}

output "discoverer_arn" {
  description = "ARN of the EventBridge Schema Discover."
  value       = var.enable_schema_discovery_registry ? aws_schemas_discoverer.this[0].arn : null
}
