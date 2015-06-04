(set-logic QF_S)
(set-info :source |  Sleek solver
  http://loris-7.ddns.comp.nus.edu.sg/~project/s2/beta/
|)

(set-info :smt-lib-version 2.0)
(set-info :category "crafted")
(set-info :status unsat)


(declare-sort node2 0)
(declare-fun val () (Field node2 Int))
(declare-fun prev () (Field node2 node2))
(declare-fun next () (Field node2 node2))

(define-fun dll ((?in node2) (?p node2) (?n Int))
Space (tospace
(or
(and 
(= ?in nil)
(= ?n 0)

)(exists ((?p_40 node2)(?self_41 node2)(?flted_12_39 Int))(and 
(= (+ ?flted_12_39 1) ?n)
(= ?p_40 ?p)
(= ?self_41 ?in)
(tobool (ssep 
(pto ?in (sref (ref val ?Anon_13) (ref prev ?p_40) (ref next ?q) ))
(dll ?q ?self_41 ?flted_12_39)
) )
)))))








































































































































(declare-fun Anon1 () Int)
(declare-fun n1 () node2)
(declare-fun n () node2)
(declare-fun p3 () node2)
(declare-fun p () node2)
(declare-fun m1 () Int)
(declare-fun q3 () node2)
(declare-fun tmpprm () node2)
(declare-fun q2 () node2)
(declare-fun x () node2)
(declare-fun yprm () node2)
(declare-fun y () node2)
(declare-fun self2 () node2)
(declare-fun xprm () node2)
(declare-fun p2 () node2)
(declare-fun q () node2)
(declare-fun flted1 () Int)
(declare-fun m () Int)


(assert 
(and 
;lexvar(= n1 n)
(= p3 p)
(= m1 flted1)
(= q3 self2)
(= tmpprm q2)
(= xprm x)
(= yprm y)
(distinct xprm nil)
(= self2 xprm)
(= p2 q)
(= (+ flted1 1) m)
(tobool  
(pto xprm (sref (ref val Anon1) (ref prev p2) (ref next q2) ))
 )
)
)

(assert (not 
;lexvar
))

(check-sat)