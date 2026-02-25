data:extend({
  {
    type = "double-setting",
    name = "bottleneck-analyzer-sample-rate",
    setting_type = "runtime-global",
    default_value = 30.0,
    minimum_value = 0.1,
    maximum_value = 300.0,
    order = "a",
  },
  {
    type = "bool-setting",
    name = "bottleneck-analyzer-enabled",
    setting_type = "runtime-global",
    default_value = true,
    order = "b",
  }
})
