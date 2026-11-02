# SH-27 early snapshot and fused declaration batch

Status: **NO GO for promotion**. Production compiler source is unchanged.

Three isolated source variants address first-visit cold work: prepare the
frontend temporary in the existing cold-key callback (using one later native
publication callback), collect declaration projection during the required
named-declaration walk, and combine both. All three independently reach exact
Stage 2/3 fixed points under the existing 256/64 MiB guards. The old projection
routine remains untouched as an oracle; these variants are not release inputs.

| Variant | Compiler SHA-256 |
| --- | --- |
| Early snapshot | `0a32587ec165e7bfdd5dbbb92493f0a27897cf0b0bc5ba05653c9fb0cca1198f` |
| Fused declarations | `dfb04a18888c0add7efc7f42a3550b0db3a294655fc9d6050ab8a2856a63e761` |
| Combined | `dd4791d7c46ff1686639588cc23c1d07c7e0b4cf8fe8fcaa9464b93bf6362eee` |

The balanced v2 matrix compares all three with `1859f47f...`, serially, under
inherited affinity mask `0xf` on the 12-logical-CPU host. Eleven pairs per
variant and an adjacent null control cover original large, control, many-file
and small workloads: 352 compile/execution samples. All executable bytes and
outputs match, with deterministic bytes and passing corpus memory guards.
The matrix's PASS means correctness; speed gain was not required.

| Workload | Null floor | Early paired delta | Fused paired delta | Combined paired delta |
| --- | ---: | ---: | ---: | ---: |
| Large functions | 28.969 ms | +0.335 ms (4/11) | -15.685 ms (7/11) | -5.225 ms (7/11) |
| Control flow | 8.839 ms | -5.827 ms (9/11) | +0.903 ms (5/11) | -7.878 ms (9/11) |
| Many files | 3.921 ms | +1.509 ms (5/11) | +6.444 ms (4/11) | +0.994 ms (4/11) |
| Small | 1.250 ms | +1.425 ms (2/11) | -0.234 ms (6/11) | +0.421 ms (5/11) |

No target variant wins above the measured null floor. No speed claim or
production source edit follows from this run. The owned source/build records
are in `build-output/z27/frontbatch/`; raw paired measurements are retained in
`build-output/z27/front-matrix11.json`, SHA-256
`7b5b5dab06adefd973b89b706debeaacfd9a670bdfdf449349fcb7de6be1e4be`.
More safety/worker-fault tests would be
needed before promotion if a future changed variant first demonstrates a gain.
