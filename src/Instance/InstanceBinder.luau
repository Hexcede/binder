--!strict
--!optimize 2

local Packages = script.Parent.Parent.Parent

local Observe = require(Packages.Observe)

local Types = require(script.Parent.Parent.Types)

type Cleanup = Types.Cleanup

type Constructor<T, B> = Types.Constructor<T, B>
type Binder<T, B> = Types.Binder<T, B>
type InstanceBinder<B> = Types.InstanceBinder<B>

local GenericBinder = require(script.Parent.Parent.Generic.GenericBinder)

local function InstanceBinder<B>(constructor: Constructor<Instance, B>): InstanceBinder<B>
    local binder = GenericBinder(constructor)

    local function Bind(tag: string): Cleanup
        return Observe.Tagged(tag, binder.Use)
    end

    local function BindIn(tag: string, container: Instance): Cleanup
        return Observe.Tagged(tag, function(instance: Instance)
            return Observe.Property(instance, "Parent", function(parent: Instance?)
                if not instance:IsDescendantOf(container) then
                    return
                end

                return binder.Use(instance)
            end)
        end)
    end

    local self = {
        Has = binder.Has,
        Get = binder.Get,

        Use = binder.Use,

        GetAddedSignal = binder.GetAddedSignal,
        GetRemovedSignal = binder.GetRemovedSignal,

        Observe = binder.Observe,

        Add = binder.Add,
        Remove = binder.Remove,

        Bind = Bind,
        BindIn = BindIn,
    }

    return self
end

return InstanceBinder