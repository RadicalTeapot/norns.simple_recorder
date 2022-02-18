local arm_strategy = include('lib/arm_strategy')
local direct_strategy = include('lib/direct_strategy')
---@type Event_subscriber
local event_subscriber = include('lib/event_subscriber')

---@class Playing_handler
local Playing_handler = {}

local playing_changed_event = event_subscriber.new()
local armed_changed_event = event_subscriber.new()

local function allow() return true end
local function playing_changed_event_trigger(state) playing_changed_event:trigger(state) end
local function armed_changed_event_trigger(state) armed_changed_event:trigger(state) end
local direct = direct_strategy.new(allow, playing_changed_event_trigger)
local arm = arm_strategy.new(allow, armed_changed_event_trigger, playing_changed_event_trigger)

function Playing_handler.get_player(use_direct)
    if use_direct then
        return direct
    else
        return arm
    end
end

---Add callback to playing state change trigger
---@param callback fun(...) Function to be called when playing state changes
function Playing_handler.register_playing_changed_callback(callback) playing_changed_event:subscribe(callback) end

---Add callback to armed state change trigger
---@param callback fun(...) Function to be called when armed state changes
function Playing_handler.register_armed_changed_callback(callback) armed_changed_event:subscribe(callback) end

function Playing_handler.register_midi_callbacks(register_start_callback, register_stop_callback)
    arm:register_midi_callbacks(register_start_callback, register_stop_callback)
end

return Playing_handler
