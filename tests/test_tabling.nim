## Variant tabling: left recursion terminates and agrees with ordinary search.
import minikanren
import algorithm
import sequtils

proc edge(x, y: RTerm): Goal =
  conde(@[
    conj(`==`(x, rint(1)), `==`(y, rint(2))),
    conj(`==`(x, rint(2)), `==`(y, rint(3))),
    conj(`==`(x, rint(3)), `==`(y, rint(4)))
  ])

proc pathRight(x, y: RTerm): Goal =
  conde(@[
    edge(x, y),
    fresh(proc(z: RTerm): Goal = conj(edge(x, z), pathRight(z, y)))
  ])

proc pathLeft(x, y: RTerm): Goal =
  tabled(@[x, y], conde(@[
    edge(x, y),
    fresh(proc(z: RTerm): Goal = conj(pathLeft(x, z), edge(z, y)))
  ]))

let rightQ = freshVar()
let leftQ = freshVar()
let ordinary = run(rightQ, pathRight(rint(1), rightQ), 20).mapIt($it).sorted()
let tabledAnswers = run(leftQ, pathLeft(rint(1), leftQ), 20).mapIt($it).sorted()
assert ordinary == @["2", "3", "4"]
echo "ordinary=", ordinary, " tabled=", tabledAnswers
assert tabledAnswers == ordinary
echo "ok: left-recursive path terminates with the right-recursive answers"

proc appendo(xs, ys, zs: RTerm): Goal =
  conde(@[
    conj(`==`(xs, rnil()), `==`(ys, zs)),
    fresh3(proc(h, t, r: RTerm): Goal =
      conj(`==`(xs, rpair(h, t)),
      conj(`==`(zs, rpair(h, r)), appendo(t, ys, r))))
  ])

proc tabledAppendo(xs, ys, zs: RTerm): Goal =
  tabled(@[xs, ys, zs], appendo(xs, ys, zs))

let a1 = freshVar(); let b1 = freshVar()
let a2 = freshVar(); let b2 = freshVar()
let ordinarySplits = run(rpair(a1, b1),
                         appendo(a1, b1, rlist(@[rint(1), rint(2)])), 10)
let tabledSplits = run(rpair(a2, b2),
                       tabledAppendo(a2, b2, rlist(@[rint(1), rint(2)])), 10)
assert ordinarySplits.mapIt($it).sorted() == tabledSplits.mapIt($it).sorted()
echo "ok: tabled appendo agrees with ordinary appendo"

proc membero(x, xs: RTerm): Goal =
  fresh2(proc(h, t: RTerm): Goal =
    conj(`==`(xs, rpair(h, t)),
         disj(`==`(x, h), membero(x, t))))

proc tabledMembero(x, xs: RTerm): Goal =
  tabled(@[x, xs], fresh2(proc(h, t: RTerm): Goal =
    conj(`==`(xs, rpair(h, t)),
         disj(`==`(x, h), tabledMembero(x, t)))))

let memberQ1 = freshVar(); let memberQ2 = freshVar()
let members = rlist(@[rint(1), rint(2), rint(3)])
let ordinaryMembers = run(memberQ1, membero(memberQ1, members), 10).mapIt($it).sorted()
let tabledMembers = run(memberQ2, tabledMembero(memberQ2, members), 10).mapIt($it).sorted()
assert ordinaryMembers == @["1", "2", "3"]
assert tabledMembers == ordinaryMembers
echo "ok: tabled membero agrees with ordinary membero"

proc sudokuRow(a, b, c: RTerm): Goal =
  conj(setEqo(@[a, b, c], @[rint(1), rint(2), rint(3)]),
       branchMostConstrained(@[a, b, c]))

let s1 = freshVar(); let s2 = freshVar(); let s3 = freshVar()
let t1 = freshVar(); let t2 = freshVar(); let t3 = freshVar()
let ordinaryCsp = run(rlist(@[s1, s2, s3]), sudokuRow(s1, s2, s3), 20)
let tabledCsp = run(rlist(@[t1, t2, t3]),
                    tabled(@[t1, t2, t3], sudokuRow(t1, t2, t3)), 20)
assert ordinaryCsp.mapIt($it).sorted() == tabledCsp.mapIt($it).sorted()
echo "ok: tabled setEqo CSP agrees with ordinary search"
