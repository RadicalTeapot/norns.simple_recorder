---@class State
local State = {}
State.__index = State

---Constructor
---@param initial_state boolean
---@param allow_state_change fun(current:boolean, new:boolean):boolean Function returning wheter state is allowed to transition from current to new
---@param state_changed_callback fun(new:boolean) Function called when state changes
---@return State state New instance
function State.new(initial_state, allow_state_change, state_changed_callback)
    ---@type State
    local self = {
        state=initial_state,
        allow_state_change=allow_state_change,
        state_changed_callback=state_changed_callback
    }
    setmetatable(self, State)
    return self
end

---Get current state
---@return boolean state Current state
function State:get() return self.state end

---Update state to new state if allowed
---@param new_state boolean
function State:set(new_state)
    if self.allow_state_change(self.state, new_state) then
        self.state = new_state
        self.state_changed_callback(self.state)
    end
end

---Toggle state if allowed
function State:toggle()
    if self.allow_state_change(self.state, not self.state) then
        self.state = not self.state
        self.state_changed_callback(self.state)
    end
end

return State
