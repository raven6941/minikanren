# minikanren

A small, self-contained miniKanren for Nim: relational programming over
first-order terms, with fair interleaving search.

```nim
import minikanren

proc appendo(xs, ys, zs: RTerm): Goal =
  conde(@[
    conj(`==`(xs, rnil()), `==`(ys, zs)),
    fresh3(proc(h, t, r: RTerm): Goal =
      conj(`==`(xs, rpair(h, t)),
      conj(`==`(zs, rpair(h, r)),
           appendo(t, ys, r))))
  ])

proc membero(x, xs: RTerm): Goal =
  fresh2(proc(h, t: RTerm): Goal =
    conj(`==`(xs, rpair(h, t)),
         disj(`==`(x, h), membero(x, t))))

let q = freshVar()
echo run(q, appendo(rlist(@[rint(1), rint(2)]),
                    rlist(@[rint(3)]), q), 5)
# => @[(1 2 3)]

let m = freshVar()
echo run(m, membero(m, rlist(@[rint(1), rint(2), rint(3)])), 10)
# => @[1, 2, 3]
```

Relations run in every direction: the same `appendo` also enumerates
all splits of a list, and the same `membero` both checks membership
and generates members. The example above is `tests/test_examples.nim`
— it runs in CI, so the output shown is the output you get.

## Installation

Requires Nim >= 2.0.0. Straight from source:

```sh
nimble install https://github.com/raven6941/minikanren
```

Pinned to the release:

```sh
nimble install https://github.com/raven6941/minikanren@#v0.1.0
```

(Once minikanren is listed in the Nimble package directory, bare
`nimble install minikanren` will work too.)

The library itself has no dependencies beyond the Nim standard library
(`strutils` only). The property suite in `tests/pbt_minikanren.nim`
needs [falsify](https://github.com/raven6941/falsify) installed, but
that is a test-only dependency — `nimble test` does not need it.

## API overview

Terms — `RTerm` is a variant ref object with three cases:

| proc | meaning |
|---|---|
| `rvar(id)` / `ratom(name)` / `rpair(h, t)` | constructors |
| `rnil()` / `rint(n)` / `rlist(elems)` | conveniences (`rint` is `ratom($n)`) |
| `$t` | prints a term; proper lists print as `(1 2 3)` |

Unification — `walk(t, s)`, `occurs(id, t, s)`,
`unify(u, v, s)` (with occurs check, returns `(ok, s2)`),
`emptySubst()`.

Goals — a `Goal` is `proc(s: State): Stream`:

| proc | meaning |
|---|---|
| `` `==`(u, v) `` / `eq(u, v)` | unification (the second is a non-operator alias) |
| `` `=/=`(u, v) `` | disequality: delayed until the terms can decide it |
| `setEqo(cells, values)` | global constraint: `set(cells) == set(values)`, with naked-single propagation |
| `conj(g1, g2)` / `disj(g1, g2)` / `conde(clauses)` | conjunction, disjunction, disjunction of clauses |
| `fresh` / `fresh2` / `fresh3` / `fresh4` | introduce fresh logic variables |
| `branchMostConstrained(vars)` | fail-first search: branch on the unbound variable with the smallest current domain |
| `computeDomain(v, s)` | current domain of a variable, derived from the constraint store |

Search — the stream is explicit data, processed by an explicit
worklist, so interleaving cannot overflow the call stack:

| proc | meaning |
|---|---|
| `emptyStream()` / `singleton(s)` / `mplus(a, b)` / `bindStream(s, fn)` / `delayStream(thunk)` | stream constructors and combinators |
| `take(n, s)` | first `n` states from a stream (fair, FIFO worklist) |
| `reify(t, s)` | reify a term under a state |
| `run(q, g, n = 10)` | run a goal, reify `q` in the first `n` answers, deduplicated by rendered form |

State — `State` extends a substitution with a constraint store
(`diseqs`, `seteqs`); `emptyState()` builds one. `Subst` is
`seq[(int, RTerm)]` and `SetEqConstraint` is the `setEqo` constraint
record — both are exported if you need to inspect or build states
directly.

## What it is not

- **No tabling.** Repeated subgoals are re-solved; there is no
  memoisation of answers, and left-recursive relations can diverge
  the way they do in untabled miniKanren.
- **No constraint solver** beyond `=/=` and `setEqo`. There is no
  finite-domain arithmetic, no linear constraints, no SMT backend.
  `computeDomain` / `branchMostConstrained` derive a domain from the
  `setEqo` / `=/=` store only — enough for small CSPs (e.g. Sudoku),
  not a general FD solver.
- **No staging — yet.** Relations are interpreted by the worklist at
  runtime, and the library currently has no staging dependency. A
  staged/compiled relational program is the staging library's job
  ([raven6941/staging](https://github.com/raven6941/staging)), and this
  engine may depend on it eventually; for now it stands alone.
- **No logic-variable scoping beyond `fresh`.** Fresh variables come
  from one process-global counter (`freshCounter`), which `run` never
  resets. Do not expect fresh ids to restart between runs, and do not
  share a counter across threads.

## Known limitations (documented, not hidden)

- `run` deduplicates answers by their rendered string (`$t`). Two
  structurally distinct terms that print the same — notably
  `rint(42)` and `ratom("42")`, since `rint` is just an atom — are
  treated as one answer.
- The `$` printer flattens pairs: a pair of two lists prints as one
  flat list, so `(() (1 2))` prints as `(nil 1 2)`. The printed form
  is a display convenience, not a faithful serialisation.
- `setEqo` propagation compares ground terms by their rendered
  strings, so it shares the same conflation as the printer.
- `take` silently stops after 100,000 worklist iterations
  (`MaxIterations`); a search that hits the cap returns the answers
  found so far with no error.
- `freshCounter` is a plain global, not thread-safe, and monotonic
  for the life of the process.

## Origin

Extracted from Eponym's Track C relational engine
(`raven6941/eponym`, `src/experimental/relational/minikanren.nim`,
546 lines, stdlib-only), which Eponym's relational elaborator,
relational interpreter, and staged relational work were built on.
The extraction keeps the engine byte-identical except for one
deliberate change: Eponym's dead depth-tracking API
(`depthLimit`, `currentDepth`, `depthExceeded`, `enterRec`,
`exitRec`) and `run`'s `maxDepth` parameter were removed. No caller
in Eponym used them, and the depth limit was never actually enforced
during search — `run` re-ran the whole search per depth level and
deduplicated, which could return the same answer twice under
different fresh-variable ids. `run(q, g, n = 10)` now does a single
`take(n)`.

Eponym itself is untouched by this extraction; its
`rel_elab` / `rel_interp` / staging consumers still import Eponym's
copy. Migrating them onto this library is a separate step.

## License

MIT, Copyright (c) 2026 raven6941.
