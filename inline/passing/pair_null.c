struct pair {
  int x;
  int y;
};

int foo(struct pair* p)
/*@
  requires p::pair<a,b>
  ensures p::pair<NULL> & res=a+1;
*/
{
  int r = (*p).x + 1;
  p = null;
  return r;
}

int main()
/*@
  requires true
  ensures res=2;
*/
{
  struct pair p;
  p.x = 1;
  p.y = 1;
  foo(&p);
  return p.x + 1;
}
