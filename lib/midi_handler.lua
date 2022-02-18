-- Midi handler modules.
-- Connect callbacks to midi start / stop messages
--

local Midi_handler = {}
Midi_handler.__index = Midi_handler

local start_callbacks = {}
local stop_callbacks = {}

local function midi_event(data)
    if Midi_handler.use_midi() then
        msg = midi.to_msg(data)
        if msg.type == "start" then
            for _, callback in ipairs(start_callbacks) do
                callback()
            end
        elseif msg.type == "stop" then
            for _, callback in ipairs(stop_callbacks) do
                callback()
            end
        end
    end
end

function Midi_handler.init(use_midi)
    Midi_handler.use_midi = use_midi
end

function Midi_handler.register_start_callback(callback)
    start_callbacks[#start_callbacks+1] = callback
end

function Midi_handler.register_stop_callback(callback)
    stop_callbacks[#stop_callbacks+1] = callback
end

function Midi_handler.get_midi_device_list()
    devices = {}
    for i = 1,#midi.vports do
        local long_name = midi.vports[i].name
        local short_name = string.len(long_name) > 15 and util.acronym(long_name) or long_name
        table.insert(devices,i..": "..short_name)
    end
    return devices
end

function Midi_handler.connect(device_index)
    local device = midi.connect(device_index)
    device.event = midi_event
end

return Midi_handler
