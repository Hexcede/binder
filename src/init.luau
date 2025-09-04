--!strict
--!optimize 2

local Types = require(script.Types)

export type Cleanup = Types.Cleanup

export type Constructor<T, B> = Types.Constructor<T, B>
export type Binder<T, B> = Types.Binder<T, B>

export type InstanceBinder<B> = Types.InstanceBinder<B>

local GenericBinder = require(script.Generic.GenericBinder)
local InstanceBinder = require(script.Instance.InstanceBinder)

local Binder = {
    Generic = GenericBinder,
    Instance = InstanceBinder,
}

return Binder