resource "aws_appautoscaling_policy" "up" {
  for_each = var.scale_up_policy.enabled ? toset(["this"]) : toset([])

  name               = "${local.prefix}-up"
  policy_type        = "StepScaling"
  resource_id        = module.scaling_target.resource_id
  scalable_dimension = module.scaling_target.scalable_dimension
  service_namespace  = module.scaling_target.service_namespace

  step_scaling_policy_configuration {
    adjustment_type = "ExactCapacity"
    cooldown        = 60

    dynamic "step_adjustment" {
      for_each = range(1, var.max_containers + 1)

      content {
        scaling_adjustment = step_adjustment.value

        # If we're scaling from 0 to 1, we want the lower bound to be set to our
        # starting value, minus 1 to make it inclusive. Otherwise, we want to
        # calculate the lower bound based on the step size and current step
        # value, and add 1 to make sure we're into the next step.
        metric_interval_lower_bound = (step_adjustment.value == 1
          ? var.scale_up_policy.start - 1
          : (step_adjustment.value - 1) * var.scale_up_policy.step + 1
        )

        # If we're at the max containers, we don't want to set an upper bound
        # since we can't scale any higher. Otherwise, we calculate the upper
        # bound based on the step size and current step value, and add 1 because
        # the upper bound is exclusive.
        metric_interval_upper_bound = (step_adjustment.value == var.max_containers
          ? null
          : step_adjustment.value * var.scale_up_policy.step + 1
        )
      }
    }
  }
}

resource "aws_appautoscaling_policy" "down" {
  for_each = var.scale_down_policy.enabled ? toset(["this"]) : toset([])

  name               = "${local.prefix}-down"
  policy_type        = "StepScaling"
  resource_id        = module.scaling_target.resource_id
  scalable_dimension = module.scaling_target.scalable_dimension
  service_namespace  = module.scaling_target.service_namespace

  step_scaling_policy_configuration {
    # We've already waited for the queue to be empty for a threshold of time, so
    # we don't need a big delay here.
    adjustment_type = "ExactCapacity"
    cooldown        = 60

    step_adjustment {
      metric_interval_upper_bound = 0
      scaling_adjustment          = 0
    }
  }
}
