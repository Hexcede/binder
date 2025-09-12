--!strict
--!optimize 2

local Types = require(script.Types)

--- A function to perform some associated cleanup logic.
export type Cleanup = Types.Cleanup

--- A constructor which creates a binder object.
--- @return The instantiated binder object.
--- @return An function which will be called to perform necessary cleanup logic.
export type Constructor<T, B> = Types.Constructor<T, B>

--- A binder that binds to any luau table or object by reference (which must be a valid table index).
export type Binder<T, B> = Types.Binder<T, B>

--- A binder that binds to Roblox Instances.
export type InstanceBinder<B> = Types.InstanceBinder<B>

local GenericBinder = require(script.Generic.GenericBinder)
local InstanceBinder = require(script.Instance.InstanceBinder)

local Binder = {
    Generic = GenericBinder,
    Instance = InstanceBinder,
}

return Binder