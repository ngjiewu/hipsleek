# create a list of new results
# ================SLEEK==========================
# ================SLEEK==========================
echo "======= bperm1.slk ======"
../../sleek --en-para -tp redlog -perm bperm bperm1.slk | grep Entail > test-cases/bperm1.n
echo "======= bperm-split.slk ======"
../../sleek --en-para -tp redlog -perm bperm bperm-split.slk | grep Entail > test-cases/bperm-split.n
echo "======= bperm-combine.slk ======"
../../sleek --en-para -tp redlog -perm bperm bperm-combine.slk | grep Entail > test-cases/bperm-combine.n
echo "======= bperm-split-combine.slk ======"
../../sleek --en-para -tp redlog -perm bperm bperm-split-combine.slk | grep Entail > test-cases/bperm-split-combine.n
echo "======= barrier1.slk ======"
../../sleek --en-para -tp redlog -perm bperm barrier1.slk | grep Entail > test-cases/barrier1.n
echo "======= barrier-split.slk ======"
../../sleek --en-para -tp redlog -perm bperm barrier-split.slk | grep Entail > test-cases/barrier-split.n
echo "======= barrier-combine.slk ======"
../../sleek --en-para -tp redlog -perm bperm barrier-combine.slk | grep Entail > test-cases/barrier-combine.n
echo "======= barrier-sep.slk ======"
../../sleek --en-para -tp redlog -perm bperm barrier-sep.slk | grep Entail > test-cases/barrier-sep.n
echo "======= barrier-static.slk ======"
../../sleek --en-para -tp redlog -perm bperm barrier-static.slk | grep Entail > test-cases/barrier-static.n
echo "======= barrier-dynamic.slk ======"
../../sleek --en-para -tp redlog -perm bperm barrier-dynamic.slk | grep Entail > test-cases/barrier-dynamic.n
echo "======= barrier-dynamic2.slk ======"
../../sleek --en-para -tp redlog -perm bperm barrier-dynamic2.slk | grep Entail > test-cases/barrier-dynamic2.n
#================HIP==========================
#================HIP==========================
echo "======= while-loop.ss ======"
../../hip --en-para -tp redlog -perm bperm while-loop.ss | grep -E 'Proc|assert:' > test-cases/while-loop.n
echo "======= while-loop2.ss ======"
../../hip --en-para -tp redlog -perm bperm while-loop2.ss | grep -E 'Proc|assert:' > test-cases/while-loop2.n
echo "======= hip-bperm1.ss ======"
../../hip --en-para -tp redlog -perm bperm hip-bperm1.ss | grep -E 'Proc|assert:' > test-cases/hip-bperm1.n
echo "======= bperm-exp.ss ======"
../../hip --en-para -tp redlog -perm bperm bperm-exp.ss | grep -E 'Proc|assert:' > test-cases/bperm-exp.n
echo "======= barrier-static-primitives.ss ======"
../../hip --en-para -tp redlog -perm bperm barrier-static-primitives.ss | grep -E 'Proc|assert:' > test-cases/barrier-static-primitives.n
echo "======= barrier-static-exp1.ss ======"
../../hip --en-para -tp redlog -perm bperm barrier-static-exp1.ss | grep -E 'Proc|assert:' > test-cases/barrier-static-exp1.n
echo "======= barrier-static-exp2.ss ======"
../../hip --en-para -tp redlog -perm bperm barrier-static-exp2.ss | grep -E 'Proc|assert:' > test-cases/barrier-static-exp2.n
echo "======= barrier-static-exp3.ss ======"
../../hip --en-para -tp redlog -perm bperm barrier-static-exp3.ss | grep -E 'Proc|assert:' > test-cases/barrier-static-exp3.n
echo "======= barrier-static-complex.ss ======"
../../hip --en-para -tp redlog -perm bperm barrier-static-complex.ss | grep -E 'Proc|assert:' > test-cases/barrier-static-complex.n
echo "======= barrier-static-complex2.ss ======"
../../hip --en-para -tp redlog -perm bperm barrier-static-complex2.ss | grep -E 'Proc|assert:' > test-cases/barrier-static-complex2.n
echo "======= barrier-static-complex3.ss ======"
../../hip --en-para -tp redlog -perm bperm barrier-static-complex3.ss | grep -E 'Proc|assert:' > test-cases/barrier-static-complex3.n
echo "======= barrier-static-multiple.ss ======"
../../hip --en-para -tp redlog -perm bperm barrier-static-multiple.ss | grep -E 'Proc|assert:' > test-cases/barrier-static-multiple.n
echo "======= barrier-static-consistency.ss ======"
../../hip --en-para -tp redlog -perm bperm barrier-static-consistency.ss | grep -E 'Proc|assert:' > test-cases/barrier-static-consistency.n
echo "======= barrier-dynamic-exp1.ss ======"
../../hip --en-para -tp redlog -perm bperm barrier-dynamic-exp1.ss | grep -E 'Proc|assert:' > test-cases/barrier-dynamic-exp1.n
echo "======= barrier-dynamic-exp2.ss ======"
../../hip --en-para -tp redlog -perm bperm barrier-dynamic-exp2.ss | grep -E 'Proc|assert:' > test-cases/barrier-dynamic-exp2.n
echo "======= barrier-dynamic-exp3.ss ======"
../../hip --en-para -tp redlog -perm bperm barrier-dynamic-exp3.ss | grep -E 'Proc|assert:' > test-cases/barrier-dynamic-exp3.n
echo "======= barrier-dynamic-exp4.ss ======"
../../hip --en-para -tp redlog -perm bperm barrier-dynamic-exp4.ss | grep -E 'Proc|assert:' > test-cases/barrier-dynamic-exp4.n
echo "======= barrier-dynamic-exp5.ss (slow) ======"
../../hip --en-para -tp redlog -perm bperm barrier-dynamic-exp5.ss | grep -E 'Proc|assert:' > test-cases/barrier-dynamic-exp5.n
echo "======= barrier-dynamic-exp6.ss ======"
../../hip --en-para -tp redlog -perm bperm barrier-dynamic-exp6.ss | grep -E 'Proc|assert:' > test-cases/barrier-dynamic-exp6.n
echo "======= barrier-dynamic-exp7.ss ======"
../../hip --en-para -tp redlog -perm bperm barrier-dynamic-exp7.ss | grep -E 'Proc|assert:' > test-cases/barrier-dynamic-exp7.n
#================BENCHMARK==========================
#================BENCHMARK==========================
echo "======= splash2/code/apps/barnes/ ======"
../../hip --en-para -tp redlog -perm bperm benchmark/our-splash2/code/apps/barnes/barnes.ss | grep -E 'Proc|assert:' > test-cases/splash2/barnes.n
echo "======= splash2/code/apps/fmm/ ======"
../../hip --en-para -tp redlog -perm bperm benchmark/our-splash2/code/apps/fmm/fmm.ss | grep -E 'Proc|assert:' > test-cases/splash2/fmm.n
echo "======= splash2/code/apps/ocean/ ======"
../../hip --en-para -tp redlog -perm bperm benchmark/our-splash2/code/apps/ocean/ocean.ss | grep -E 'Proc|assert:' > test-cases/splash2/ocean.n
echo "======= splash2/code/apps/raytrace/ ======"
../../hip --en-para -tp redlog -perm bperm benchmark/our-splash2/code/apps/raytrace/raytrace.ss | grep -E 'Proc|assert:' > test-cases/splash2/raytrace.n
echo "======= splash2/code/apps/volrend/ (slow) ======"
../../hip --en-para -tp redlog -perm bperm benchmark/our-splash2/code/apps/volrend/volrend.ss | grep -E 'Proc|assert:' > test-cases/splash2/volrend.n
echo "======= splash2/code/apps/water-nsquared/ (a bit slow) ======"
../../hip --en-para -tp redlog -perm bperm benchmark/our-splash2/code/apps/water-nsquared/water-nsquared.ss | grep -E 'Proc|assert:' > test-cases/splash2/water-nsquared.n
echo "======= splash2/code/apps/water-spatial/ (a bit slow) ======"
../../hip --en-para -tp redlog -perm bperm benchmark/our-splash2/code/apps/water-spatial/water-spatial.ss | grep -E 'Proc|assert:' > test-cases/splash2/water-spatial.n
echo "======= splash2/code/kernels/cholesky/ ======"
../../hip --en-para -tp redlog -perm bperm benchmark/our-splash2/code/kernels/cholesky/cholesky.ss | grep -E 'Proc|assert:' > test-cases/splash2/cholesky.n
echo "======= splash2/code/kernels/fft/ ======"
../../hip --en-para -tp redlog -perm bperm benchmark/our-splash2/code/kernels/fft/fft.ss | grep -E 'Proc|assert:' > test-cases/splash2/fft.n
echo "======= splash2/code/kernels/fu/  (a bit slow) ======"
../../hip --en-para -tp redlog -perm bperm benchmark/our-splash2/code/kernels/lu/lu.ss | grep -E 'Proc|assert:' > test-cases/splash2/lu.n
echo "======= splash2/code/kernels/radix/ ======"
../../hip --en-para -tp redlog -perm bperm benchmark/our-splash2/code/kernels/radix/radix.ss | grep -E 'Proc|assert:' > test-cases/splash2/radix.n
echo "======= splash2/code/apps/radiosity/ ======"
#NOT YET VERIFIABLE
../../hip --en-para -tp redlog -perm bperm benchmark/our-splash2/code/apps/radiosity/radiosity.ss | grep -E 'Proc|assert:' > test-cases/splash2/radiosity.n
