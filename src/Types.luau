--!strict
--!optimize 2

local Packages = script.Parent.Parent

local Signal = require(Packages.Signal)

export type Signal<T...> = Signal.Signal<T...>

export type Cleanup = () -> ()

export type Constructor<T, B> = (object: T) -> (B, Cleanup?)

export type Binder<T, B> = {
    Has: (object: T) -> boolean,
    Get: (object: T) -> B?,

    GetAddedSignal: (object: T) -> Signal<B>,
    GetRemovedSignal: (object: T) -> Signal<B>,

    Observe: (object: T, callback: (binder: B) -> Cleanup?) -> Cleanup,

    Add: (object: T) -> B,
    Remove: (object: T) -> (),
}

export type InstanceBinder<B> = Binder<Instance, B> & {
    Bind: (tag: string) -> Cleanup,
    BindIn: (tag: string, container: Instance) -> Cleanup,
}

return nil