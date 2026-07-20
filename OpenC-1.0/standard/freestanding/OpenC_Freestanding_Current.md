# OpenC Freestanding Environment 1.0 — authored current baseline

Status: **AUTHOR-FINAL FOR SOURCE HANDOFF; INDEPENDENT REVIEW AND EXECUTION PENDING**

Freestanding OpenC is Core OpenC without implicit Hosted services. It is intended for kernels, firmware, boot code, embedded systems, device runtimes, and constrained target environments.

## 1. No implicit facilities

Freestanding conformance does not imply:

```text
process entry or exit
console streams
filesystem
path services
dynamic allocation
wall-clock or monotonic time
threads
locale
environment variables
Hosted standard-library modules
```

Using an unavailable facility produces a capability diagnostic or a link-time provider error recorded by the build tool. The compiler cannot silently substitute a build-host service.

## 2. Target context

A freestanding project declares, at minimum:

```text
target identity
pointer width
endianness
fixed-width type availability
maximum object size
alignment guarantees
entry symbol/startup contract
checked-failure provider
target-fault provider
available runtime hooks
```

These facts participate in build records and reproducibility data.

## 3. Entry and startup

The target integration supplies an entry symbol and startup path. It may call an ordinary OpenC function chosen by project configuration. Freestanding Core does not reserve `main` or assume a process exit status.

Startup is responsible for:

```text
initializing required memory regions
establishing the stack and target runtime state
installing checked-failure and target-fault hooks
calling the configured OpenC entry function
handling any returned target-defined value
```

## 4. Required runtime hooks

The first-party freestanding runtime declares hooks equivalent to:

```text
write diagnostic bytes, when available
allocate/release bytes, when available
checked failure
unsafe target fault
terminal halt or target-defined return
```

A target may omit optional hooks. A program depending on an omitted hook is not a conforming build for that target.

## 5. Allocation

Dynamic allocation is optional. When absent, programs use fixed arrays, typed storage, static storage established by target integration, or explicitly supplied allocators from a non-Core component.

When provided, allocation obeys the same Core ownership, alignment, and lifetime rules as Hosted allocation. Allocation failure remains visible through the provider contract.

## 6. Checked failures and target faults

Freestanding targets must define how a checked failure and an unsafe target fault terminate or transfer control. The behavior may halt, reset, trap to a monitor, or return to a target supervisor, but it must be declared and bounded. It is never arbitrary optimizer permission.

## 7. Capability records

Freestanding build context lists every facility used by the program. Capability presence is reproducible and included in build and conformance records.

## 8. First-party source boundary

The authored hooks and default fail-closed implementation live under `runtime/freestanding/`. They are not claimed as integrated with any real target. A target port must provide its own hook implementation and startup record before conformance can be claimed.
