// tll with parent working example

struct node{
  struct node* parent;
  struct node* left;
  struct node* right;
  struct node* next;
};

/* predicate for a non-empty tree with chained leaf list */
/*@
tll<p,ll,lr> == self::node<p,D1,null,lr> & self = ll
    or self::node<p,l,r,D2> * l::tll<self,ll,z> * r::tll<self,z,lr> & r!=null
	inv self!=null;
*/
/* predicate for a non-empty tree  */
/*@
tree<> == self::node<_,D1,null,_>
  or self::node<_,l,r,D2> * l::tree<> * r::tree<> & r!=null
	inv self!=null;
*/
// initializes the linked list fields
/*@
  HeapPred H(node a, node@NI p, node@NI b).
  HeapPred G(node a, node@NI p, node@NI b, node@NI c).
*/
struct node* set_right (struct node* p, struct node* x, struct node* t)
/*@
  infer [H,G] 
  requires H(x,p,t) 
  ensures G(x,p,res,t) ;
*/
// requires x::tree<p> ensures x::tll<p,res,t>;
{
  x->parent = p;
  if (x->right==NULL) {
    x->next = t;
    return x;
  }
  else {
    struct node* l_most = set_right(x,x->right, t);
    return set_right(x,x->left, l_most);
  }
}

/*
# tll-parent.ss --pred-en-dangling

*/
