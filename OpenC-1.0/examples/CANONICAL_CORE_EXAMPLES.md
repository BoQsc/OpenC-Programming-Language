# OpenC Core Candidate 2 — Canonical Examples

## Direct function declaration

```c
i32 add(i32 a, i32 b) {
    return a + b;
}
```

## Logical module import

```c
import math.basic;

export i32 calculate(i32 value) {
    return basic.double(value);
}
```

## Optional presence

```c
optional i32 value = none;

if value.present {
    return value.value;
}

return 0;
```

## Recoverable output

```c
i32 value;
status result = parse(out value);

if !result.ok {
    return result.code;
}

return value;
```

## Resource and cleanup

```c
Buffer buffer = buffer_create(1024);
scope buffer_destroy(buffer);

buffer_write(buffer, data);
```

## Raw pointer boundary

```c
i32 value = 10;

unsafe {
    ptr i32 address = &value;
    *address = 20;
}
```

## Typed storage

```c
storage Player slot;
ref Player player = construct(slot, Player{ health = 100 });
scope destroy(player);
```


## Primitive typed storage

```c
storage i32 slot;
ref i32 value = construct(slot, 42);
scope destroy(value);
```

## Explicit arithmetic variants

```c
i32 wrapped = wrap_add(2147483647, 1);
i32 limited = saturating_add(2147483647, 1);
```

## Closed switch execution

```c
switch direction {
    case Direction.north { return 1; }
    case Direction.east  { return 2; }
    case Direction.south { return 3; }
    case Direction.west  { return 4; }
}
```
