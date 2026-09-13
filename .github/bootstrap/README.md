# OpenC bootstrap seed

`openc-stage0.exe` is the byte-exact SH-25 OpenC 1.0 compiler, built from the
OpenC sources at commit `d861216f4bb533fcf4818849048dcf02b2a0c864`.

SHA-256:
`eadbef1f065261385c2c36d524624347f7e5cd3c021a4a1db9ccfcaf7c191087`

It is retained only so a clean Windows runner can rebuild the compiler from
source without D, TinyCC, generated C, an assembler, or an external linker.
The rebuilt compiler must reproduce this hash before it may run the release
workflow. The compiler code is licensed under 0BSD as documented by the
canonical OpenC tree.
