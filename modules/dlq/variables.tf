variable "kms_key_id" {
  description = "The ID of the existing KMS key."
  type        = string
}

variable "queue_name" {
  description = "The name of the queue to create. -dlq will be appended to the end. The name should the [bus-name]-[rule-name] convention."
  type        = string
}

variable "tags" {
  description = "Tags help you manage, identify, organize search and filter resources."
  type        = map(string)
}
