/**
* # EventBus Dead Letter Queue (DLQ) Sub Module
*
* This module creates a SQS queue that can be used by Amazon EventBridge as a DLQ.
*/
data "aws_caller_identity" "current" {}
