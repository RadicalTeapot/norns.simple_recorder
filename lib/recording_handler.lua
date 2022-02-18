local arm_strategy = include('lib/arm_strategy')
local direct_strategy = include('lib/direct_strategy')
---@type Event_subscriber
local event_subscriber = include('lib/event_subscriber')

---@class Recording_handler
local Recording_handler = {}

local recording_changed_event = event_subscriber.new()
local armed_changed_event = event_subscriber.new()

local arm
local direct
local function allow_arm_state_change(_, next_state)
    -- Always allow to disarm but only allow arm when not playing
    return (not next_state) or (not arm:playing())
end

local function allow() return true end
local function recording_changed_event_trigger(state) recording_changed_event:trigger(state) end
local function armed_changed_event_trigger(state) armed_changed_event:trigger(state) end
local direct = direct_strategy.new(allow, recording_changed_event_trigger)
arm = arm_strategy.new(allow_arm_state_change, armed_changed_event_trigger, recording_changed_event_trigger)

local function change_arm_when_recording(state)
    -- If armed and starting to record, disarm
    if arm:get() and state then
        arm:set(false)
    end
end
recording_changed_event:subscribe(change_arm_when_recording)

function Recording_handler.get_recorder(use_direct)
    if use_direct then
        return direct
    else
        return arm
    end
end

---Add callback to recording state change trigger
---@param callback fun(...) Function to be called when playing state changes
function Recording_handler.register_recording_changed_callback(callback) recording_changed_event:subscribe(callback) end

---Add callback to armed state change trigger
---@param callback fun(...) Function to be called when armed state changes
function Recording_handler.register_armed_changed_callback(callback) armed_changed_event:subscribe(callback) end

function Recording_handler.register_midi_callbacks(register_start_callback, register_stop_callback)
    arm:register_midi_callbacks(register_start_callback, register_stop_callback)
end

return Recording_handler
