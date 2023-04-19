variable "kms_key_id" {
  description = "The ID of the existing KMS key. If empty, then a new key will be created with permissions for EventBridge."
  type        = string
  default     = ""
}

variable "queue_name" {
  description = "The name of the queue to create. -dlq will be appended to the end. The name should the [bus-name]-[rule-name] convention."
  type        = string
}

variable "tags" {
  description = "Tags help you manage, identify, organize search and filter resources."
  type        = map(string)
}

locals {
  kms_count  = var.kms_key_id == "" ? 1 : 0
  kms_key_id = local.kms_count == 1 ? aws_kms_key.this[0].id : var.kms_key_id
}
