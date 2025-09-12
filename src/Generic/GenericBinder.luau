--!strict
--!optimize 2

local Packages = script.Parent.Parent.Parent

local Observe = require(Packages.Observe)
local Signal = require(Packages.Signal)

local Types = require(script.Parent.Parent.Types)

type Signal<T...> = Types.Signal<T...>

type Cleanup = Types.Cleanup

type Constructor<T, B> = Types.Constructor<T, B>
type Binder<T, B> = Types.Binder<T, B>

local WEAK_KEYS = table.freeze({ __mode = "k" })

local function GenericBinder<T, B>(constructor: Constructor<T, B>): Binder<T, B>
    local addedSignals: { [T]: Signal<B> } = setmetatable({}, WEAK_KEYS) :: any
    local removedSignals: { [T]: Signal<B> } = setmetatable({}, WEAK_KEYS) :: any

    local bindings = {}
    local unbinders = {}

    local function Has(object: T): boolean
        return not not unbinders[object]
    end

    local function Get(object: T): B?
        return bindings[object]
    end

    local function Add(object: T): B
        if Has(object) then
            return Get(object) :: B
        end

        local binding, cleanup = constructor(object)

        local function unbind()
            if cleanup then
                cleanup()
                cleanup = nil
            end

            local removedSignal = removedSignals[object]

            if removedSignal then
                removedSignal:Fire(binding)
            end

            bindings[object] = nil
            unbinders[object] = nil
        end

        bindings[object] = binding
        unbinders[object] = unbind

        local addedSignal = addedSignals[object]

        if addedSignal then
            addedSignal:Fire(binding)
        end

        return binding
    end

    local function Remove(object: T): ()
        local unbind = unbinders[object]

        if not unbind then
            return
        end

        unbind()
    end

    local function GetAddedSignal(object: T): Signal<B>
        local addedSignal = addedSignals[object]

        if addedSignal then
            return addedSignal
        end

        local signal = Signal.new()

        addedSignals[object] = signal

        return signal
    end

    local function GetRemovedSignal(object: T): Signal<B>
        local removedSignal = removedSignals[object]

        if removedSignal then
            return removedSignal
        end

        local signal = Signal.new()

        removedSignals[object] = signal

        return signal
    end

    local function ObserveBinder(object: T, callback: (binder: B) -> Cleanup?): Cleanup
        local addedSignal = GetAddedSignal(object)
        local removedSignal = GetRemovedSignal(object)

        return Observe.SetClearSignals(Get(object), addedSignal, removedSignal, function(binder: B?)
            if not binder then
                return
            end

            return callback(binder)
        end)
    end

    local self = {
        Has = Has,
        Get = Get,

        GetAddedSignal = GetAddedSignal,
        GetRemovedSignal = GetRemovedSignal,

        Observe = ObserveBinder,

        Add = Add,
        Remove = Remove,
    }

    return self
end

return GenericBinder