--!strict
--!optimize 2
--!nolint LocalShadow

local Packages = script.Parent.Parent.Parent

local Observe = require(Packages.Observe)
local Signal = require(Packages.Signal)

local Types = require(script.Parent.Parent.Types)

type Signal<T...> = Types.Signal<T...>

type Cleanup = Types.Cleanup

type Constructor<T, B> = Types.Constructor<T, B>
type Binder<T, B> = Types.Binder<T, B>
type Use<T, B> = Types.Use<T, B>
type Add<T, B> = Types.Add<T, B>

local WEAK_KEYS = table.freeze({ __mode = "k" })

local function GenericBinder<T, B>(constructor: Constructor<T, B>): Binder<T, B>
    local addedSignals: { [T]: Signal<B> } = setmetatable({}, WEAK_KEYS) :: any
    local removedSignals: { [T]: Signal<B> } = setmetatable({}, WEAK_KEYS) :: any

    local constructorThreads = {}
    local awaitingConstructorThreads = {}

    local bindings = {}
    local unbinders = {}

    local refCounts = {}

    local function Has(object: T): boolean
        return not not unbinders[object]
    end

    local function Get(object: T): B?
        return bindings[object]
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

    local function Await(object: T): B
        local addedSignal = GetAddedSignal(object)

        while not Has(object) do
            addedSignal:Wait()
        end

        return Get(object) :: B
    end

    local function TryConstruct(object: T, onFailure: Cleanup?): (B, Cleanup?)
        local constructorThread = constructorThreads[object]
        local awaitingThreads = awaitingConstructorThreads[object]

        -- If we're expecting construction to get completed by another thread already
        if awaitingThreads and constructorThread and coroutine.status(constructorThread) ~= "dead" then
            assert(coroutine.isyieldable(), `Can't await asynchronous construction in a non-yieldable context`)

            -- Wait for construction to finish
            awaitingThreads[coroutine.running()] = true
            local success, binding = coroutine.yield()

            if success then
                return binding, nil
            end

            -- Allow the object to be gracefully reconstructed in the future
            -- TODO: Should this be an error instead?
            return Await(object)
        end

        local awaitingThreads: { [thread]: boolean } = if awaitingThreads then table.clone(awaitingThreads) else {}

        awaitingConstructorThreads[object] = awaitingThreads
        constructorThreads[object] = coroutine.running()

        local success, binding, cleanup = xpcall(constructor, debug.traceback, object)

        -- If construction isn't valid anymore (e.g. cancelled by removal), clean up the constructed object
        if awaitingConstructorThreads[object] ~= awaitingThreads then
            if cleanup then
                cleanup()
            end

            -- Allow the object to be gracefulyl reconstructed in the future
            return Await(object)
        end

        constructorThreads[object] = nil
        awaitingConstructorThreads[object] = nil

        -- Notify all of the waiting threads that the constructor finished
        for thread, _ in awaitingThreads do
            task.spawn(thread, success, binding)
        end

        if not success then
            -- Run failure callback before finishing so that refs can get cleaned up
            if onFailure then
                onFailure()
            end

            error(`Error during construction: {binding}`, 2)
        end

        return binding, cleanup
    end

    local function Add(object: T, onFailure: Cleanup?): B
        if Has(object) then
            return Get(object) :: B
        end

        local binding, cleanup = TryConstruct(object, onFailure)

        local function unbind()
            if cleanup then
                cleanup()
                cleanup = nil
            end

            local removedSignal = removedSignals[object]

            if removedSignal then
                removedSignal:Fire(binding)
            end

            refCounts[object] = nil

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
        -- Remove the constructor thread so that the result gets discarded
        constructorThreads[object] = nil
        awaitingConstructorThreads[object] = nil

        local unbind = unbinders[object]

        if not unbind then
            return
        end

        unbind()
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

    local function Use(object: T, onFailure: Cleanup?): (Cleanup, B)
        refCounts[object] = (refCounts[object] or 0) + 1

        local isCleaned = false

        local function cleanup()
            if isCleaned then
                return
            end

            isCleaned = true

            -- Decrement the reference count for the object
            local refCount = refCounts[object] - 1

            refCounts[object] = refCount

            if refCount > 0 then
                return
            end

            -- Defer & clean up the object if there are no remaining references
            task.defer(function()
                if refCounts[object] > 0 then
                    return
                end

                Remove(object)
            end)
        end

        local binder = Add(object, function()
            if Has(object) then
                cleanup()
            else
                refCounts[object] -= 1
            end

            if onFailure then
                onFailure()
            end
        end)

        return cleanup, binder
    end

    local self: Binder<T, B> = {
        Has = Has,
        Get = Get,
        Await = Await,

        Use = Use :: Use<T, B>,

        GetAddedSignal = GetAddedSignal,
        GetRemovedSignal = GetRemovedSignal,

        Observe = ObserveBinder,

        Add = Add :: Add<T, B>,
        Remove = Remove,
    }

    return self
end

return GenericBinder