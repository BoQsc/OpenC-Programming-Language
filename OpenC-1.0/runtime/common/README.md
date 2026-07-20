
# Common runtime source

Status: **SOURCE-AUTHORED; NOT COMPILED OR EXECUTED**

Two bootstrap runtime layers are included:

```text
runtime/source/openc/runtime/*.d
    canonical D bootstrap/runtime library used by the D-source backend

runtime/common/source/openc_runtime.[ch]
    portable C ABI runtime used as an alternative native bootstrap boundary
```

Both are implementation mechanisms. Neither defines OpenC semantics independently of the current standard.
