output "arn" {
  value       = aws_sqs_queue.dlq.arn
  description = "The ARN of the dead letter queue."
}

output "kms_id" {
  value       = local.kms_key_id
  description = "The ID of the KMS used by the queue."
}
