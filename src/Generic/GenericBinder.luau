--!strict
--!optimize 2

local Types = require(script.Parent.Parent.Types)

type Cleanup<T, B> = Types.Cleanup

type Constructor<T, B> = Types.Constructor<T, B>
type Binder<T, B> = Types.Binder<T, B>

local function GenericBinder<T, B>(constructor: Constructor<T, B>): Binder<T, B>
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

            bindings[object] = nil
            unbinders[object] = nil
        end

        bindings[object] = binding
        unbinders[object] = unbind

        return binding
    end

    local function Remove(object: T): ()
        local unbind = unbinders[object]

        if not unbind then
            return
        end

        unbind()
    end

    local self = {
        Has = Has,
        Get = Get,

        Add = Add,
        Remove = Remove,
    }

    return self
end

return GenericBinder