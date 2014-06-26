(set-logic QF_S)
(set-info :source |  Sleek solver
  http://loris-7.ddns.comp.nus.edu.sg/~project/s2/beta/
|)

(set-info :smt-lib-version 2.0)
(set-info :category "crafted")
(set-info :status unsat)


(declare-sort node 0)
(declare-fun nxt () (Field node node))

(define-fun elseg ((?in node) (?p node))
Space (tospace
(or
(= ?in ?p)
(exists ((?a node)(?b node))(and 
(tobool (ssep 
(pto ?in  (ref nxt ?a))
(pto ?a  (ref nxt ?b))
(elseg ?b ?p)
) )
)))))











(define-fun right ((?in node) (?p node))
Space (tospace
(exists ((?u node))(and 
(tobool (ssep 
(elseg ?in ?u)
(elseg ?u ?p)
) )
))))




(declare-fun a () node)
(declare-fun b () node)
(declare-fun z () node)
(declare-fun p () node)


(assert 
(and 
(tobool (ssep 
(pto z  (ref nxt a))
(pto a  (ref nxt b))
(elseg b p)
) )
)
)

(assert (not 
(and 
(tobool  
(right z p)
 )
)
))

(check-sat)