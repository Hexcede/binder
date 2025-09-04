--!strict
--!optimize 2

export type Cleanup = () -> ()

export type Constructor<T, B> = (object: T) -> (B, Cleanup?)

export type Binder<T, B> = {
    Has: (object: T) -> boolean,
    Get: (object: T) -> B?,

    Add: (object: T) -> B,
    Remove: (object: T) -> (),
}

export type InstanceBinder<B> = Binder<Instance, B> & {
    Bind: (tag: string) -> Cleanup,
    BindIn: (tag: string, container: Instance) -> Cleanup,
}

return nil