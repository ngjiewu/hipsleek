
relation P(int x, int y).

int zip(int x,int y)
 infer[P]
 requires P(x,y) & x>=0 & y>=0
 ensures true;
{
  if (x==0) return x;
  else {
    int r=zip(x-1,y-1);
    return 1+r;
  }
}

/*
# ex24c --ops

!!! **typechecker.ml#564:inf_o_lst:[]
!!! **WARNING****typechecker.ml#844:if important : need to add to estate.es_infer_rel
!!! **typechecker.ml#845:WARNING : Spurious RelInferred (not collected):[RELASS [P]: ( P(x,y)) -->  (x<=0 | (1<=x & y!=0)),RELDEFN P: ( P(x,y) & y=v_int_11_1754'+1 & x=v_int_11_1755'+1 & 0<=(1+v_int_11_1754') & 
 0<=v_int_11_1755') -->  P(v_int_11_1755',v_int_11_1754')]
Procedure zip$int~int SUCCESS.


!!! **pi.ml#686:lst_assume (after norm and postprocess):[( P(x,y), (x<=0 | (1<=x & y!=0)))]
!!! PROBLEM with fix-point calculation
ExceptionFailure("get_unchanged_fixpoint: Invalid rel")Occurred!


*/
