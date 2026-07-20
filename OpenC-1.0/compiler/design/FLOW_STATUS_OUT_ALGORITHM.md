# Flow, Optional, and Status/Out Algorithm

Build a CFG with explicit edges for branches, loops, switch cases, structured exits, and checked-failure edges.

Track per binding:

```text
initialization: uninitialized / initialized / maybe-initialized
optional: absent / present / unknown
out: conditional(lineage) / resolved-success / resolved-failure / ambiguous
ownership: uninitialized / live / cleanup-reserved / moved / maybe-live / ambiguous
borrow sets and reachability
```

An out call creates one proof-lineage identity shared by its status result and every output. Direct status copies preserve lineage. Ordinary bool copies do not. At merges, facts survive only when every continuing predecessor agrees; terminating predecessors do not participate.

Losing the last unresolved proof carrier is diagnosed. On success, every output commits transactionally; on failure, none commits. Owning outputs begin exactly one ownership obligation only after success proof.
