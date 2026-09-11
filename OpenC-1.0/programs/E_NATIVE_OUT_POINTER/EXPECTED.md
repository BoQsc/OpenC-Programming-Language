# E — native `out ptr` runtime output

The program must exit with status `0` after reading `VERSION` through
`system.file.read_bytes_raw`, checking the returned pointer and length, and
freeing the buffer.

This is the maintained regression for the SH-21 native backend defect where an
`out ptr` argument could be lowered as the uninitialized pointer value instead
of the address of its local storage.
