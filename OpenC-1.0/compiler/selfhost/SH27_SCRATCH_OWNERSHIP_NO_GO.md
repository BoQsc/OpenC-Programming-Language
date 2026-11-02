# SH-27 per-source scratch ownership: no-go before compiler build

Status: **static/microprobe triage only; no compiler candidate built or
promoted**. This isolated branch starts at production source
dd8adc6d5a3f664e13abee59f81b7990b631d780. The source constructor and
release functions are unchanged from the 6794d56 profiler baseline.

## Bound and mechanism

c_emit_source_record makes 42 unprofiled source-constructor requests and
c_release_source_context frees them at source end. Opt-in type-query
profiling adds one array, giving the published **43 requests/source**. The
native allocator maps memory.alloc to HeapAlloc(HEAP_ZERO_MEMORY) after
the live-byte reservation, and memory.free to HeapFree. A single
source-scoped arena could remove most calls and their small per-allocation
headers, but it would still zero and use essentially the same sparse cache
payload. Reusing an arena across sources would require moving its ownership
from source context to each worker and resetting every live cache; retaining
four high-water arenas could worsen strict 64/256 MiB self-build peaks.

The opt-in probe counted 344 requests / 101,490,936 requested bytes on eight
large-function sources and 172 / 23,312,496 bytes on four control-flow
sources. These are cumulative, **not peak live bytes**. The unprofiled
critical-worker wall account leaves only 31 ms large / 16 ms control outside
indexing, acceptance, IR lowering, and native emission, an optimistic ceiling
for this scratch-only tactic. The clean same-host two-lane speed screen has a
10 ms null floor on each lane.

## Bounded native heap proxy

measure_sh27_scratch_heap.py reconstructs the 43-request/source size shape
from the constructor's four IR buffers, syntax-sized arrays,
source-position arrays, and two symbol-sized arrays. It matches each
workload's published cumulative requested bytes. It alternates 43 paired
split-versus-single-arena Win32 process-heap trials, with and without
explicit page touch. Python/ctypes call overhead and omission of arena
bookkeeping both favor the arena, so this is an optimistic proxy, **not a
measured OpenC compiler speedup or formal upper bound**. The maximum live
request in a trial is one source's roughly 12.69 MB large or 5.83 MB
control, and no compiler build runs concurrently.

| Paired median split minus one arena | Eight large sources | Four control sources |
| --- | ---: | ---: |
| HeapAlloc(HEAP_ZERO_MEMORY) / HeapFree only | 48.7 ms | 10.1 ms |
| Same plus explicit page touch | 25.1 ms | 4.3 ms |

The production four-worker critical chunk contains **two** large sources
or **one** control source in the checked matrix. Scaling this deliberately
arena-favorable serial proxy to the affected critical chunk gives roughly
12.2/6.3 ms large and **2.5/1.1 ms control**, respectively. The control
estimate is well below the clean 10 ms null floor even before arena
bookkeeping, cache resets, scheduling, and RAM risk. Removing one of the 43
requests in production reduces the plausible gain further. A single arena
does not remove payload bytes; its explicit allocation-header saving is
only about 41 × 16 = 656 bytes per source, plus allocator metadata.

Raw local proxy samples are an ignored artifact at
build-output/sh27-scratch-ownership/heap-proxy-01.json in this worktree.

## Decision

Do **not** spend a guarded Stage 1/2/3 build, strict 20-generation RAM run,
or 11+11 paired matrix on a scratch-only arena/reuse cut. The code mechanism
and optimistic control-lane proxy cannot credibly clear the same-host gain
gate, let alone close C/D parity. This is a no-go hypothesis, not proof that
allocation time is universally zero. Revisit scratch ownership only as part
of a larger architecture that demonstrably removes first-visit semantic
work or establishes a safe per-worker prepared-source boundary; then measure
the actual allocator time and strict peaks on that exact source.
