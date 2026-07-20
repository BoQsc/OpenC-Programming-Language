
# Freestanding runtime source

Status: **SOURCE-AUTHORED; TARGET INTEGRATION AND EXECUTION PENDING**

Freestanding source includes:

```text
runtime/freestanding/startup.d
runtime/freestanding/source/openc_platform_freestanding.c
runtime/source/openc/runtime/freestanding.d
```

The default provider fails closed for unavailable Hosted facilities and exposes weak hooks for a target integrator to replace. It does not pretend that console, filesystem, allocator, or process services exist.
