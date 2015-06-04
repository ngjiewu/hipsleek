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








































































































































(declare-fun Anon29 () Int)
(declare-fun Anon31 () Int)
(declare-fun q28 () node2)
(declare-fun self24 () node2)
(declare-fun q26 () node2)
(declare-fun x () node2)
(declare-fun a () Int)
(declare-fun aprm () Int)
(declare-fun xprm () node2)
(declare-fun p27 () node2)
(declare-fun p () node2)
(declare-fun n () NUM)
(declare-fun p29 () node2)
(declare-fun self22 () node2)
(declare-fun flted35 () Int)
(declare-fun flted33 () Int)
(declare-fun lprm () node2)


(assert 
(and 
;lexvar(= lprm q28)
(= self24 q26)
(= xprm x)
(= aprm a)
(< a n)
(< 0 a)
(= aprm 1)
(= self22 xprm)
(= p27 p)
(= (+ flted33 1) n)
(= p29 self22)
(= (+ flted35 1) flted33)
(= lprm nil)
(tobool (ssep 
(pto xprm (sref (ref val Anon29) (ref prev p27) (ref next q26) ))
(pto self24 (sref (ref val Anon31) (ref prev p29) (ref next q28) ))
(dll q28 self24 flted35)
) )
)
)

(assert (not 
(and 
(tobool  
(pto xprm (sref (ref val val24prm) (ref prev prev24prm) (ref next next24prm) ))
 )
)
))

(check-sat)