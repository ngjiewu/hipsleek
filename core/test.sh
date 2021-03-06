#create a list of expected results
echo "======= ptr-byptr.ss ======"
../hip ptr-byptr.ss > test/ptr-byptr.res
echo "======= ptr-byval.ss ======"
../hip ptr-byval.ss > test/ptr-byval.res
echo "======= ptr-byref.ss ======"
../hip ptr-byref.ss > test/ptr-byref.res
echo "======= ptr-globalptr.ss ======"
../hip ptr-globalptr.ss > test/ptr-globalptr.res
echo "======= ptr-global.ss ======"
../hip ptr-global.ss > test/ptr-global.res
echo "======= ptr-local.ss ======"
../hip ptr-local.ss > test/ptr-local.res
echo "======= ptr-ifthenelse.ss ======"
../hip ptr-ifthenelse.ss > test/ptr-ifthenelse.res
echo "======= ptr-while.ss ======"
../hip ptr-while.ss > test/ptr-while.res
echo "======= address-of-var.ss ======"
../hip address-of-var.ss > test/address-of-var.res
echo "======= ptr-of-ptr.ss ======"
../hip ptr-of-ptr.ss > test/ptr-of-ptr.res
echo "======= ptr-proc.ss ======"
../hip ptr-proc.ss > test/ptr-proc.res
echo "======= ptr-proc-fork.ss ======"
../hip ptr-proc-fork.ss > test/ptr-proc-fork.res
echo "======= while-w-heap.ss ======"
../hip while-w-heap.ss > test/while-w-heap.res
echo "======= ptr-while-addr.ss ======"
../hip ptr-while-addr.ss > test/ptr-while-addr.res
echo "======= ptr-ref1.ss ======"
../hip ptr-ref1.ss > test/ptr-ref1.res
echo "======= ptr-ref2.ss ======"
../hip ptr-ref2.ss > test/ptr-ref2.res
echo "======= ptr-ref3.ss ======"
../hip ptr-ref3.ss > test/ptr-ref3.res
echo "======= ptr-ref4.ss ======"
../hip ptr-ref4.ss > test/ptr-ref4.res
echo "======= ptr-ref5.ss ======"
../hip ptr-ref5.ss > test/ptr-ref5.res
