## tests/test_examples.nim — the README example, as a runnable test.
## appendo and membero, run forwards and backwards.
## Run: nim c -r --hints:off --path:src tests/test_examples.nim
import minikanren
import algorithm
import sequtils

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

# appendo forwards: [1, 2] ++ [3] = [1, 2, 3]
let q1 = freshVar()
let fwd = run(q1, appendo(rlist(@[rint(1), rint(2)]),
                          rlist(@[rint(3)]), q1), 5)
assert fwd.len == 1 and $fwd[0] == "(1 2 3)"
echo "ok: appendo forwards: [1,2] ++ [3] = ", $fwd[0]

# appendo backwards: all splits of [1, 2] (order is search order;
# compare as a set)
let a = freshVar()
let b = freshVar()
let splits = run(rpair(a, b),
                 appendo(a, b, rlist(@[rint(1), rint(2)])), 10)
assert splits.len == 3
# Note the printer flattens pairs: a pair of two lists prints as one
# flat list, e.g. (() (1 2)) prints as "(nil 1 2)". See README.
assert splits.mapIt($it).sorted() ==
  @["((1) 2)", "((1 2))", "(nil 1 2)"].sorted()
echo "ok: appendo backwards: splits of [1,2] = ", splits.mapIt($it)

# membero forwards: enumerate the members of [1, 2, 3]
let q2 = freshVar()
let members = run(q2, membero(q2, rlist(@[rint(1), rint(2), rint(3)])), 10)
assert members.mapIt($it).sorted() == @["1", "2", "3"]
echo "ok: membero enumerates: ", members.mapIt($it)

# membero backwards: 2 is a member, 9 is not
let q3 = freshVar()
assert run(q3, membero(rint(2), rlist(@[rint(1), rint(2), rint(3)])), 1).len == 1
let q4 = freshVar()
assert run(q4, membero(rint(9), rlist(@[rint(1), rint(2), rint(3)])), 1).len == 0
echo "ok: membero checks membership (2 in, 9 out)"

echo "--- all example tests passed ---"
