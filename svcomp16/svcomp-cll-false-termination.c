#include "../examples/working/cparser/stdhip.h"
struct node {
  int val;
  struct node* next;
};

struct node* new_lseg(struct node* p, int n)
{
  if (n==0)
    return p;
  struct node *x = malloc(sizeof *x);
  x->next = new_lseg(p, n-1);
  return x;
}

struct node* new_cll(int n)
{
  struct node *x = malloc(sizeof *x);
  x->next = new_lseg(x,n-1);
  return x;
}

void main()
{
  int n = 10;
  struct node *xs = new_cll(n);
  while (xs != NULL)
  {
     xs = xs->next;
  }
}
