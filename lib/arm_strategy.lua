---@type State
local state = include('lib/state_manager')

local Arm = {}
Arm.__index = Arm

local start = function(self)
    if self.arm_state:get() and (not self.playing_state:get()) then
        self.playing_state:set(true)
    end
end

local stop = function(self)
    if self.playing_state:get() then
        self.playing_state:set(false)
    end
end

function Arm.new(allow_state_change, state_change_callback, playing_state_change_callback)
    local self = {
        playing_state = state.new(false, function() return true end, playing_state_change_callback),
        arm_state = state.new(false, allow_state_change, state_change_callback),
    }
    setmetatable(self, Arm)
    return self
end

function Arm:playing() return self.playing_state:get() end

function Arm:armed() return self.arm_state:get() end

function Arm:stop_playing() stop(self) end

function Arm:get() return self.arm_state:get() end

function Arm:set(state) self.arm_state:set(state) end

function Arm:toggle() self.arm_state:toggle() end

function Arm:register_midi_callbacks(register_start_callback, register_stop_callback)
    register_start_callback(function() start(self) end)
    register_stop_callback(function() stop(self) end)
end

return Arm
