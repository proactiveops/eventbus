variable "name" {
  description = "The name of the eventbus or partner source. This must be unique per region per account."
  type        = string
}

variable "allow_put_events_arns" {
  description = "List of ARNs allowed to call PutEvents on this instance. Used for resource based cross account/region access."
  type        = list(string)
  default     = []
}

variable "bus_policy_docs" {
  description = "List of additional IAM policy documents to append to the access policy for this instance. Ignored if using a partner bus. Generally you will want to use `allow_put_events_arns` over this."
  type        = list(string)
  default     = []
}

variable "cross_bus_rules" {
  description = "List of cross bus routing rules."
  type = list(
    object(
      {
        name       = string                 # Name of the rule
        target_arn = string                 # ARN of the target event bus
        pattern    = string                 # JSON string representation of event pattern used for matching events
        debug      = optional(bool, false)  # Enable debug logging for this rule
        dlq_arn    = optional(string, null) # ARN of the dead letter queue to use for this rule
      }
    )
  )
  default = []
}

variable "enable_schema_discovery_registry" {
  description = "Enable the EventBridge schema discovery resource."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags for resources created by module."
  type        = map(string)
  validation {
    condition     = alltrue([for t in ["environment"] : contains(keys(var.tags), t)])
    error_message = "environment tag is required"
  }
}

locals {
  is_partner_source = startswith(var.name, "aws.partner")
  namespace         = local.is_partner_source ? local.event_source_name : "${lower(var.name)}-${lower(var.tags.environment)}"
  namespace_clean   = replace(local.namespace, "/[^a-z0-9]/", "-")
}
