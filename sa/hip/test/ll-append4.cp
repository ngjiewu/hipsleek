HeapPred HP_619(node next_96_565').
HeapPred HP_614(node y_613, node y).
HeapPred HP_583(node next_96_565', node x').
HeapPred HP_612(node a, node b).
HeapPred HP_619(node a).
HeapPred HP1(node a, node b).
HeapPred G3(node b, node c, node d).
HeapPred G1(node a).
HeapPred G2(node a, node b).
HeapPred H2(node a, node b).
HeapPred H1(node a).
HeapPred H(node a).

append[
ass [H1,G2]: {
 HP_583(v_node_96_600,x) * x::node<val_96_589,y>&v_node_96_600=null -->  G2(x,y)&true;
 H1(x)&true -->  x::node<val_96_564',next_96_565'> * HP_583(next_96_565',x)&true;
 HP_583(v_node_96_606,x)&v_node_96_606!=null -->  H1(v_node_96_606)&true;
 x::node<val_96_591,v_node_96_606> * G2(v_node_96_606,y)&v_node_96_606!=null -->  G2(x,y)&true
}
hpdefs [H1,G2]: {
 HP_583(v_node_96_600)&true -->  
 v_node_96_600::node<val_96_564',next_96_565'> * HP_619(next_96_565')&true
 or emp&v_node_96_600=null
 ;
 G2(x,y)&true -->  x::node<val_96_589,y_613> * HP_614(y_613,y)&true;
 H1(x)&true -->  x::node<val_96_564',next_96_565'> * HP_619(next_96_565')&true;
 HP_614(y_613,y)&true -->  
 emp&y_613=y
 or y_613::node<val_96_589,y_617> * HP_614(y_617,y)&true
 ;
 HP_619(next_96_565')&true -->  
 emp&next_96_565'=null
 or next_96_565'::node<val_96_564',next_96_622> * HP_619(next_96_622)&true
 
}
]

