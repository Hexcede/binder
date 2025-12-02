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

    local function ObserveNearestAncestor(instance: Instance, callback: (binder: B) -> Cleanup?): Cleanup
        local lastInstance: Instance?
        local lastBinder: B?
        local cleanupBinderObserver: Cleanup?

        local isCleaned = false

        local cleanups: {Cleanup} = {}

        local function clearCleanups()
            local oldCleanups = table.clone(cleanups)

            table.clear(cleanups)

            for _, cleanup in oldCleanups do
                cleanup()
            end
        end

        local function updateTarget()
            if isCleaned then
                return
            end

            clearCleanups()

            local current = instance

            repeat
                local parent = current.Parent

                if not parent then
                    return
                end

                current = parent

                -- If the current ancestor has the binder, observe it and apply the callback
                if binder.Has(current) then
                    -- If the instance/binder reference has not actually changed, do nothing
                    if current == lastInstance and binder.Get(current) == lastBinder then
                        break
                    end

                    if cleanupBinderObserver then
                        cleanupBinderObserver()
                    end

                    lastInstance = current
                    lastBinder = nil

                    cleanupBinderObserver = binder.Observe(current, function(binder)
                        lastBinder = binder

                        local cleanup = callback(binder)

                        return function()
                            lastBinder = nil

                            if cleanup then
                                cleanup()
                            end

                            if isCleaned then
                                return
                            end

                            task.defer(updateTarget)
                        end
                    end)

                    break
                end

                local addedConnection = binder.GetAddedSignal(current):Once(updateTarget)

                table.insert(cleanups, function()
                    addedConnection:Disconnect()
                end)
            until not current
        end

        local ancestryChanged = instance.AncestryChanged:Connect(updateTarget)

        updateTarget()

        local function cleanup()
            isCleaned = true

            if cleanupBinderObserver then
                cleanupBinderObserver()
            end

            clearCleanups()

            ancestryChanged:Disconnect()
        end

        return cleanup
    end

    local self = {
        Has = binder.Has,
        Get = binder.Get,

        Use = binder.Use,

        GetAddedSignal = binder.GetAddedSignal,
        GetRemovedSignal = binder.GetRemovedSignal,

        Observe = binder.Observe,
        ObserveNearestAncestor = ObserveNearestAncestor,

        Add = binder.Add,
        Remove = binder.Remove,

        Bind = Bind,
        BindIn = BindIn,
    }

    return self
end

return InstanceBinder