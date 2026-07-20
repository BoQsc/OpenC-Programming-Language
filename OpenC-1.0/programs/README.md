# Maintained OpenC programs

The authored acceptance targets are:

```text
A_COMPUTATION       Core values, modules, aggregates, enum switch, checked arithmetic
B_FLOW_OWNERSHIP    status/out, resources, ownership movement, scope cleanup
C_UNSAFE_BOUNDARY   typed storage, raw pointers, unsafe, safe wrapper
D_HOSTED_CLI        minimum Hosted console and process-argument behavior
```

Each directory contains source, an `openc.project.json`, and an expected-result record.

Evidence state: **4 OF 4 CHECKED, BUILT, AND EXECUTED SUCCESSFULLY ON THE RECORDED WINDOWS HOST**.

`tests/run_maintained.py` verifies the expected exit code and exact Hosted output. The project records retain their Linux target context, so this local bootstrap execution is not native Linux verification.
