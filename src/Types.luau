--!strict
--!optimize 2

local Packages = script.Parent.Parent

local Signal = require(Packages.Signal)

export type Signal<T...> = Signal.Signal<T...>

export type Cleanup = () -> ()

export type Constructor<T, B> = (object: T) -> (B, Cleanup?)

export type Use<T, B> =
    & (object: T) -> (Cleanup, B)
    & (object: T, onFailure: Cleanup?) -> (Cleanup, B)

export type Add<T, B> =
    & (object: T) -> B
    & (object: T, onFailure: Cleanup?) -> B

export type Binder<T, B> = {
    --- @return Whether or not the object has a binder instantiated.
    Has: (object: T) -> boolean,
    --- @return The intantiated binder, if any.
    Get: (object: T) -> B?,
    --- Waits for the binder to be added. Does not try to construct it.
    --- @return The instantiated binder.
    Await: (object: T) -> B,

    --- Creates or retrieves the binder for the object and retains a reference to it.
    --- Once no more references to the binder exist it will be garbage collected.
    --- @return A cleanup function which releases the used binder reference.
    --- @return The instantiated binder.
    Use: Use<T, B>,

    --- @return A signal that fires when the binder is added.
    GetAddedSignal: (object: T) -> Signal<B>,
    --- @return A signal that fires when the binder is removed.
    GetRemovedSignal: (object: T) -> Signal<B>,

    --- Observes the instantiated binder for the given object, if any.
    --- @return A function that cleans up the observer.
    Observe: (object: T, callback: (binder: B) -> Cleanup?) -> Cleanup,

    --- Creates (or retrieves) the binder for the given object.
    --- @return The instantiated binder.
    Add: Add<T, B>,
    --- Removes the binder from the object & cleans it up.
    Remove: (object: T) -> (),
}

export type InstanceBinder<B> = Binder<Instance, B> & {
    --- Binds to the given `CollectionService` tag and automatically instantiates & cleans up binders using `.Use`.
    --- @return A function which unbinds the tag
    Bind: (tag: string) -> Cleanup,
    --- Binds to the given `CollectionService` tag within the given container and automatically instantiates & cleans up binders using `.Use`.
    --- @return A function which unbinds the tag
    BindIn: (tag: string, container: Instance) -> Cleanup,

    --- Searches for the first ancestor that has the binder, excluding the given instance.
    --- @return The binding, if any
    FindFirstAncestor: (instance: Instance) -> B?,
    --- Observes an instantiated binder on the first ancestor for the given object, excluding itself.
    --- @return A function that cleans up the observer.
    ObserveFirstAncestor: (instance: Instance, callback: (binder: B) -> Cleanup?) -> Cleanup,
}

return nil