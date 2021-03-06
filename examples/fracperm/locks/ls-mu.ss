/*
  Test l.mu and LSMU
*/

LOCK<> == self::lock<>
  inv self!=null
  inv_lock true;

lemma "splitLock" self::LOCK(f)<> & f=f1+f2 & f1>0.0 & f2>0.0  -> self::LOCK(f1)<> * self::LOCK(f2)<> & 0.0<f<=1.0;

void func(lock l1)
  requires l1::LOCK(0.5)<> & l1 notin LS & l1.mu>0
  ensures l1::LOCK(0.5)<> & LS'=LS;//'
{
  acquire[LOCK](l1);
  release[LOCK](l1);
}

void func_acquire(lock l1)
  requires l1::LOCK(0.5)<> & l1 notin LS & l1.mu>0
  ensures l1::LOCK(0.5)<> & LS'=union(LS,{l1});//'
{
  acquire[LOCK](l1);
}

void func_release(lock l1)
  requires l1::LOCK(0.5)<> & l1 in LS & l1.mu>0
  ensures l1::LOCK(0.5)<> & LS'=diff(LS,{l1});//'
{
  release[LOCK](l1);
}

//test initialization and finalization
void f1()
  requires LS={}
  ensures LS'={}; //'
{
  int level = 100;
  lock l1 = new lock(level);
  
  //initialization
  init[LOCK](l1);
  release[LOCK](l1);
  
  //
  acquire[LOCK](l1);
  release[LOCK](l1);
  
  //finalization
  acquire[LOCK](l1);
  finalize[LOCK](l1);
  
}

//test sequential procedure calls
void f2()
  requires LS={}
  ensures LS'={}; //'
{
  int level = 100;
  lock l1 = new lock(level);
  //initialization
  
  init[LOCK](l1);
  release[LOCK](l1);
  
  //sequential call
  func(l1);

  //
  acquire[LOCK](l1);
  release[LOCK](l1);

  
}

//test fork/join
void f3()
  requires LS={}
  ensures LS'={}; //'
{
  int level = 100;
  lock l1 = new lock(level);
  //initialization
  
  init[LOCK](l1);
  release[LOCK](l1);
  
  //
  int id = fork(func,l1);
  
  //
  acquire[LOCK](l1);
  release[LOCK](l1);
  
  //
  join(id);
  
}

//test non-lexical acquire/release
void f4()
  requires LS={}
  ensures LS'={}; //'
{
  int level = 100;
  lock l1 = new lock(level);
  
  //initialization
  init[LOCK](l1);
  release[LOCK](l1);
  
  //
  func_acquire(l1);
  
  //
  func_release(l1);
  
  //
  acquire[LOCK](l1);
  release[LOCK](l1);
  
  //
}

//test fork/join and non-lexical acquire/release
void f5()
  requires LS={}
  ensures LS'={}; //'
{
  int level = 100;
  lock l1 = new lock(level);
  
  //initialization
  init[LOCK](l1);
  release[LOCK](l1);
  
  //
  int id = fork(func,l1);
  
  //
  func_acquire(l1);
  
  //
  func_release(l1);
  
  //
  join(id);
  
  //
  acquire[LOCK](l1);
  release[LOCK](l1);
  
  //
}

