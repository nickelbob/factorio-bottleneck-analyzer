data:extend({
  {
    type = "shortcut",
    name = "bottleneck-analyzer-toggle",
    action = "lua",
    icon = "__bottleneck-analyzer__/icon-64.png",
    icon_size = 64,
    small_icon = "__bottleneck-analyzer__/icon.png",
    small_icon_size = 32,
    toggleable = true,
    associated_control_input = "bottleneck-analyzer-toggle-key",
    order = "b[blueprints]-z[bottleneck-analyzer]",
  },
  {
    type = "custom-input",
    name = "bottleneck-analyzer-toggle-key",
    key_sequence = "CONTROL + B",
    action = "lua",
    order = "a",
  },
})
