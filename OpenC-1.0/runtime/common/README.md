
# Common runtime source

Status: **D BOOTSTRAP RUNTIME BUILT/TESTED; PORTABLE C ABI SOURCE UNVERIFIED**

Two bootstrap runtime layers are included:

```text
runtime/source/openc/runtime/*.d
    legacy bootstrap/runtime library used by the retained D-source backend

runtime/common/source/openc_runtime.[ch]
    required C ABI runtime used by the standalone OpenC compiler
```

Both are implementation mechanisms. The C ABI layer plus the Windows provider
is the verified standalone runtime path. The D layer is optional historical
audit material. Neither defines OpenC semantics independently of the current
standard.
