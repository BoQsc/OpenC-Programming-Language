
# Common runtime source

Status: **D BOOTSTRAP RUNTIME BUILT/TESTED; PORTABLE C ABI SOURCE UNVERIFIED**

Two bootstrap runtime layers are included:

```text
runtime/source/openc/runtime/*.d
    canonical D bootstrap/runtime library used by the D-source backend

runtime/common/source/openc_runtime.[ch]
    portable C ABI runtime used as an alternative native bootstrap boundary
```

Both are implementation mechanisms. The D layer is the verified Windows
bootstrap runtime; the portable C ABI layer remains an alternative,
out-of-scope provider. Neither defines OpenC semantics independently of the
current standard.
