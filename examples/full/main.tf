/**
 * Example of using EventBus++ module with multiple event buses and cross-bus rules.
 */

module "eventbus_dlq_example" {
  source = "../../modules/dlq"

  queue_name = "example"
  tags       = local.tags
}

module "eventbus_partner" {
  source = "../../"

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
