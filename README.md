# EventBus++ for Amazon EventBridge

EventBus++ is a Terraform module for deploying a managed instance of Amazon’s EventBridge and associated services. The instance is configured with sane defaults and options to extend the functionality for the needs of your application.

## Using this Module
The most minimal implementation of this module can be deployed by including the following terraform block:

```hcl2
module "eventbus_example" {
  source = "git::ssh://git@github.com/proactiveops/eventbus?ref=main"

  name = "example"

  tags = {
    environment = "dev"
  }
}
```

In the example above a new EventBridge instance will be deployed with the name `example-dev`.

### Debugging targets
EventBus++ makes it easy to enable debugging on a cross bus rule. When enabled on a target it logs all events to a CloudWatch Log group.

`debug` is optional and it defaults to `false`. When set to `true` to create all the necessary resources required for debugging rules managed by EventBus++.

You can configure this feature with the following code
```hcl2
module "eventbus_debug" {
  source = "git::ssh://git@github.com/proactiveops/eventbus?ref=main"

  name = "example"
  # ...
  cross_bus_rules = [
    {
      name       = "cross_bus_test_rule",
      pattern    = jsonencode({ "source" = ["event-source"] }),
      target_arn = "arn:aws:events:us-east-1:012345678910:event-bus/target"
      debug      = true
    }
  ]

  tags = {
    environment = "dev"
  }
}
```

### Adding Dead Letter Queues
For most rules there should be a Dead Letter Queue (DLQ). EventBus++ makes it easy to configure a DLQ for a cross bus rule. The 'dlq\_arn' property is optional, so if it is omitted it won't be configured.

You can configure this feature with the following code:

```hcl2
module "eventbus_dlq" {
  source = "git::ssh://git@github.com/proactiveops/eventbus?ref=main"

  name = "example"
  # ...
  cross_bus_rules = [
    {
      name       = "cross_bus_test_rule",
      pattern    = jsonencode({ "source" = ["event-source"] }),
      target_arn = "arn:aws:events:us-east-1:012345678910:event-bus/target"
      dlq_arn    = module.eventbus_dlq_config.dlq_arn
    }
  ]

  tags = {
    environment = "dev"
  }
}
```

EventBus++ includes a sub module for creating an encrypted SQS queue that can be used as a DLQ. This queue created by the DLQ sub module can be passed to a cross bus rule via the `dlq\_arn` property in the rule config. See [the DLQ submodule](#dlq-sub-module) for details on how to use this module.

## Rules
Within AWS EventBridge event routing is broken up into two parts - rules and targets. Rules specify a pattern to match events. The rule doesn’t route the event.

While it is possible to implement complex rules for matching events, this can make debugging in production more difficult. Aim for simpler rules where ever possible, your future self will thank you.

Here is an example of a simple rule which matches all deployment completed events.

```hcl2
resource "aws_cloudwatch_event_rule" "example_deployment_complete" {
  name           = "deployments-complete"
  description    = "Capture deployment complete events from my-service"
  event_bus_name = module.eventbus_example.eventbridge.name # Needed so we listen to the correct bridge instance.

  event_pattern = jsonencode({
    "source" : ["my-service"],
    "detail-type" : ["deployment-completed"]
  })
}
```

[Amazon’s documentation on event pattern matching](https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-event-patterns.html) provides more examples of matching rules. For full details of the configuration options for the `aws_cloudwatch_event_rule` resource, refer to the [terraform documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule).

The [default limit of rules per event bus is 300](https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-quota.html#eb-limits). This can be raised by [requesting a quota increase](https://console.aws.amazon.com/servicequotas/home?region=us-east-1#!/services/events/quotas) if you have a business need for a higher quota.

## Targets
Once we have our rules, we need to use targets to route our events to another service.

In this example we are routing our deployment complete events to an SQS queue in the same account.

```hcl2
resource "aws_cloudwatch_event_target" "example_deployment_complete_to_sqs" {
  rule           = aws_cloudwatch_event_rule.example_deployment_complete.name
  target_id      = "example-deployment-complete-to-sqs"
  arn            = aws_sqs_queue.this.arn
  event_bus_name = aws_cloudwatch_event_rule.example_deployment_complete.event_bus_name
}
```

You may need to configure the resource policy on the target resource before it accepts your events. Amazon provides [example resource policies for common services](https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-use-resource-based.html).

For other resources or cross account routing you will need to provision an IAM role for the bridge to assume when sending the events.

If you need to route events from one EventBus++ instance to another, you can use the `cross_bus_rules` variable to simplify your setup. Each map in the list will provision the rule, target and IAM role for you. Each `name` property must be unique for each bus to avoid conflicts. The `pattern` property is any valid event matching pattern. See [rules](#rules) section above for event pattern matching configuration.

```hcl2
module "eventbus_example" {
  source = "git::ssh://git@github.com/proactiveops/eventbus?ref=main"

  name = "example"

  cross_bus_rules = [
    {
      name       = "cross_bus_test_rule",
      pattern    = jsonencode({ "source" = ["event-source"] }),
      target_arn = "arn:aws:events:us-east-1:012345678910:event-bus/target"
      debug      = true
    },
    # ...
  ]

  tags = {
    environment = "dev"
  }
}
```

The list of [supported EventBridge targets](https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-targets.html) is growing all the time. If a target isn’t supported, you can use a Lambda function to invoke the API call with your event payload.

For all available configuration options for the `aws_cloudwatch_event_target` resource, [refer to the terraform documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target).

Both the [AWS]( https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-transform-target-input.html) and [terraform](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target#input-transformer-usage---json-object) documentation provide examples of using input transformers to manipulate events before sending them to the target. This is a useful feature if you only need some of the event payload to be sent to the target.

## Receiving Events
Each EventBridge instance provisioned by EventBus++ has a resource policy attached to it that implements IAM controls, so that roles in the same account can be granted access to the bridge.  Granting the `events:PutEvents` action on your bridge resource is enough to allow the role access.

When sending events from another account, additional configuration is required. The `allow_put_events_arns` variable allows you to specify a list of EventBridge rule ARNs that can send events to the bridge. An example of this is included below.

```hcl2
module "eventbus_put_events" {
  source = "git::ssh://git@github.com/proactiveops/eventbus?ref=main"

  name = "example"

  allow_put_events_arns = [
    "arn:aws:events:us-east-1:012345678910:rule/EventBus-example-dev/my-rule",
    # ...
  ]

  tags = {
    environment = "dev"
  }
}
```

If you require more complex rules, you can pass a list of `data.aws_iam_policy_document.json` strings to the EventBus++ module using the `bus_policy_docs` variable. An example of this is included below.

```hcl2
data "aws_iam_policy_document" "example_document" {
  # ...
}

module "eventbus_bus_policies" {
  source = "git::ssh://git@github.com/proactiveops/eventbus?ref=main"

  name = "example"

  bus_policy_docs = [data.aws_iam_policy_document.example_document.json]

  allow_put_events_arns = [
    "arn:aws:events:us-east-1:012345678910:rule/EventBus-example-dev/my-rule",
    # ...
  ]

  tags = {
    environment = "dev"
  }
}
```
## dlq Sub Module

The dlq sub module provisions a new SQS queue that can be used as Dead Letter Queue (DLQ). It will optionally create a new KMS key for encrypting the messages at rest.

A single DLQ can be used for more than one rule.

Add the sub module to your terraform module like so:

```hcl
module "eventbus_dlq_example" {
  source = "git::ssh://git@github.com/proactiveops/eventbus//modules/dlq?ref=main"

  queue_name = "[sub-name]-[optional-rule-name]" # Must not exceed 60 characters as the module appends "-dlq" to the name
  kms_key_id = aws_kms_key.my_key.id             # omit if you want a new KMS key to be created.
  tags       = var.tags
}

## Support

EventBus++ is built and maintained by [ProactiveOps](https://proactiveops.com/). A newsletter produced by Dave Hall Consulting. If you have any questions or need help, please [contact us](https://davehall.com.au/contact/).
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0, < 2.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 4.0, <6.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.94.1 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_event_archive.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_archive) | resource |
| [aws_cloudwatch_event_bus.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_bus) | resource |
| [aws_cloudwatch_event_bus_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_bus_policy) | resource |
| [aws_cloudwatch_event_rule.targets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) | resource |
| [aws_cloudwatch_event_target.targets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_cloudwatch_event_target.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_cloudwatch_log_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_iam_policy.events_cross_account](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.events_cross_account](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.events_cross_account](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_schemas_discoverer.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/schemas_discoverer) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_cloudwatch_event_source.partner](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/cloudwatch_event_source) | data source |
| [aws_iam_policy_document.event_bus](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.events_assume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.events_cross_account](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_allow_put_events_arns"></a> [allow\_put\_events\_arns](#input\_allow\_put\_events\_arns) | List of ARNs allowed to call PutEvents on this instance. Used for resource based cross account/region access. | `list(string)` | `[]` | no |
| <a name="input_bus_policy_docs"></a> [bus\_policy\_docs](#input\_bus\_policy\_docs) | List of additional IAM policy documents to append to the access policy for this instance. Ignored if using a partner bus. Generally you will want to use `allow_put_events_arns` over this. | `list(string)` | `[]` | no |
| <a name="input_cross_bus_rules"></a> [cross\_bus\_rules](#input\_cross\_bus\_rules) | List of cross bus routing rules. | <pre>list(<br/>    object(<br/>      {<br/>        name       = string                 # Name of the rule<br/>        target_arn = string                 # ARN of the target event bus<br/>        pattern    = string                 # JSON string representation of event pattern used for matching events<br/>        debug      = optional(bool, false)  # Enable debug logging for this rule<br/>        dlq_arn    = optional(string, null) # ARN of the dead letter queue to use for this rule<br/>      }<br/>    )<br/>  )</pre> | `[]` | no |
| <a name="input_enable_schema_discovery_registry"></a> [enable\_schema\_discovery\_registry](#input\_enable\_schema\_discovery\_registry) | Enable the EventBridge schema discovery resource. | `bool` | `true` | no |
| <a name="input_name"></a> [name](#input\_name) | The name of the eventbus or partner source. This must be unique per region per account. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags for resources created by module. | `map(string)` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_bus"></a> [bus](#output\_bus) | The bus resource created by this module. |
| <a name="output_cross_bus_rules_arns"></a> [cross\_bus\_rules\_arns](#output\_cross\_bus\_rules\_arns) | ARNs of cross bus rules created for this bus. |
| <a name="output_discoverer_arn"></a> [discoverer\_arn](#output\_discoverer\_arn) | ARN of the EventBridge Schema Discover. |
<!-- END_TF_DOCS -->