# Ownership, Borrow, and Cleanup Algorithm

## Ownership

Represent each resource or owning-pointer obligation as an abstract identity independent of bytes. Resource construction reserves stable source owners and commits all transfers atomically. A pre-commit checked failure releases reservations without moving sources.

## Movement

Movement occurs only through declared `own` boundaries and domain-specific functions. After transfer, the source binding is moved. A consuming resource function either transfers the whole resource or discharges every visible nested slot exactly once.

## Borrows

Permit many read borrows or one mutable borrow. Use final-use analysis to end local borrows early. A borrow cannot outlive its owner, cross destruction, justify movement, or coexist with conflicting mutation.

## Cleanup

A `scope` action resolves its callee and captures its narrow argument forms at registration. Consuming cleanup reserves one ownership obligation. Structured exit executes all actions in reverse registration order. Eligible cleanup is exported no-fail; a safe wrapper may contain proven internal unsafe work. Fallible finish/flush/commit operations remain explicit ordinary control flow.
