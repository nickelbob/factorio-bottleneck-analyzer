local perf_log = {}

local LOG_FILE = "bottleneck-analyzer-perf.jsonl"
local enabled = false
local tick_buffer = {}
local buffer_count = 0
local FLUSH_INTERVAL = 120

function perf_log.is_enabled()
  return enabled
end

function perf_log.enable()
  enabled = true
  tick_buffer = {}
  buffer_count = 0
  helpers.write_file(LOG_FILE, "", false)
end

function perf_log.disable()
  if not enabled then return end
  if buffer_count > 0 then
    helpers.write_file(LOG_FILE, table.concat(tick_buffer, "", 1, buffer_count), true)
  end
  enabled = false
  tick_buffer = {}
  buffer_count = 0
end

function perf_log.log_tick(tick, batch, proc, inv, wait, chit, cmis, ent, cur)
  if not enabled then return end
  buffer_count = buffer_count + 1
  tick_buffer[buffer_count] = '{"t":"tk","tick":' .. tick
    .. ',"batch":' .. batch
    .. ',"proc":' .. proc
    .. ',"inv":' .. inv
    .. ',"wait":' .. wait
    .. ',"chit":' .. chit
    .. ',"cmis":' .. cmis
    .. ',"ent":' .. ent
    .. ',"cur":' .. cur
    .. '}\n'

  if buffer_count >= FLUSH_INTERVAL then
    helpers.write_file(LOG_FILE, table.concat(tick_buffer, "", 1, buffer_count), true)
    tick_buffer = {}
    buffer_count = 0
  end
end

function perf_log.log_sweep(tick, start_tick, ent, inv, wait, chit, cmis, rec)
  if not enabled then return end

  if buffer_count > 0 then
    helpers.write_file(LOG_FILE, table.concat(tick_buffer, "", 1, buffer_count), true)
    tick_buffer = {}
    buffer_count = 0
  end

  helpers.write_file(LOG_FILE, '{"t":"sw","tick":' .. tick
    .. ',"start":' .. start_tick
    .. ',"dur":' .. (tick - start_tick)
    .. ',"ent":' .. ent
    .. ',"inv":' .. inv
    .. ',"wait":' .. wait
    .. ',"chit":' .. chit
    .. ',"cmis":' .. cmis
    .. ',"rec":' .. rec
    .. '}\n', true)
end

return perf_log
