int foo(int i)
/*@
  requires i = 0
  ensures res = 2;
*/
{
  if (i != 0) {
    goto label1;
    i = i + 1;
  label1: i = i + 2;
  return i;
  } else {
    goto label2;
    i = i + 1;
  label2: return 2;
  }
}
