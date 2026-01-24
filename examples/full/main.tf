resource "aws_kms_key" "this" {
  description = "EvenBus Example"

  deletion_window_in_days = 14
  enable_key_rotation     = true

  tags = local.tags
}

resource "aws_kms_alias" "this" {
  name          = "alias/eventbus-example"
  target_key_id = aws_kms_key.this.key_id
}

module "eventbus_dlq_example" {
  source = "../../modules/dlq"

  kms_key_id = aws_kms_alias.this.arn
  queue_name = "example"

  tags = local.tags
}

module "eventbus_partner" {
  source = "../../"

  # Note: Zendesk no longer supports EventBridge partnet buses.
  name = "aws.partner/zendesk.com/12345678/default"

  cross_bus_rules = [
    {
      name       = "all_tickets_to_internal",
      pattern    = jsonencode({ "source" = [{ prefix = "aws.partner/zendesk.com/" }] }),
      target_arn = module.eventbus_internal.bus.arn
      debug      = true
      dlq_arn    = module.eventbus_dlq_example.arn
    }
  ]

  tags = local.tags
}

module "eventbus_internal" {
  source = "../../"

  name = "internal"
  allow_put_events_arns = [
    module.eventbus_partner.cross_bus_rules_arns["all_tickets_to_internal"],
  ]

  tags = local.tags
}


locals {
  tags = {
    environment = "dev"
  }
}

terraform {
  required_version = ">= 1.0, < 2.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0, <7.0"
    }
  }
}
