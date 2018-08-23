import cpp
import semmle.code.cpp.valuenumbering.HashCons

// Every expression should have exactly one GVN.
// So this query should have zero results.
from Expr e
where count(hashCons(e)) != 1
select e, concat(HC h | h = hashCons(e) | h.getKind(), ", ")
