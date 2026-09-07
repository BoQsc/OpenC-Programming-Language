# OpenC Windows modules

The Windows friendly modules are hand-authored OpenC source. They expose typed
resources and `status` results, with UTF-8 `text` at the public boundary and
temporary UTF-16 buffers for Windows Unicode APIs.

| Module | Initial interface |
| --- | --- |
| `windows.foundation` | UTF conversion, owned text buffers, error capture/formatting |
| `windows.file` | Read/create/replace, byte buffers, writes, flush, remove |
| `windows.memory` | Process/private heaps, allocate, consuming resize, release |
| `windows.process` | Start, wait, exit code, process-handle cleanup |
| `windows.thread` | Current thread ID, sleep, event creation/signaling/waiting |
| `windows.console` | UTF-8 output to a console or redirected stream |
| `windows.window` | Desktop handle, validity, title, message box |
| `windows.graphics` | Device contexts, solid brushes, rectangle fill |
| `windows.resources` | Executable path, module load/unload |
| `windows.network` | Winsock session lifetime and host name |
| `windows.registry` | Current-user key access and text values |
| `windows.shell` | Local application-data directory and shell open |

This is the initial supported API surface; it does not imply a complete GUI,
socket, process-control, or registry framework. The generated `windows.raw.*`
packages preserve the underlying metadata separately.

## Ownership and failure

Check `status.ok` before reading an `out` result. Use the matching consuming
cleanup function for each resource, directly or through a local `scope` cleanup
adapter. File, process and event handles use `CloseHandle`; brushes use
`DeleteObject`; device contexts use `ReleaseDC`; private heaps use `HeapDestroy`;
loaded modules use `FreeLibrary`; registry keys use `RegCloseKey`; Winsock sessions
use `WSACleanup`. Borrowed desktop/process-heap handles are not destroyed.

Free heap blocks before destroying their heap. `memory.resize` consumes the old
block on both success and failure; a successful call returns its replacement.
`foundation.view` is unsafe because its text borrows the owned buffer: the buffer
must remain alive throughout every use of the view.

File `create_new` refuses to replace an existing file. Replacement requires the
explicit `replace` operation. Process creation takes an application path and a
Windows command line; callers remain responsible for command-line quoting.
The friendly API uses documented Windows functions and does not make direct
syscalls. Optional subsystem DLLs load from the Windows system directory.

## Building and verification

Register the friendly source modules in the consuming project. The complete
example is `tests/sh18_windows_modules/openc.project.json`; package registration
is also in `standard_library/openc.project.json`. Automatic discovery of arbitrary
standard-library imports is not provided by this milestone.

Run `python scripts/verify_sh18_windows_modules.py --compiler PATH_TO_OPENC`
for the Windows behavior probe and import audit. The general compiler currently
uses generated C, TinyCC, and a C provider, and these programs import `msvcrt.dll`.
Replacing that backend/provider is SH-19. Python is the external verifier, not a
child dependency of `openc build`. The separate SH-16 direct-PE runtime proof
remains CRT-free.
