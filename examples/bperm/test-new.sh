#create a list of new results
#================SLEEK==========================
#================SLEEK==========================
echo "======= bperm1.slk ======"
../../sleek bperm1.slk | grep Entail > test-cases/bperm1.n
echo "======= bperm-split.slk ======"
../../sleek bperm-split.slk | grep Entail > test-cases/bperm-split.n
echo "======= bperm-combine.slk ======"
../../sleek bperm-combine.slk | grep Entail > test-cases/bperm-combine.n
echo "======= bperm-split-combine.slk ======"
../../sleek bperm-split-combine.slk | grep Entail > test-cases/bperm-split-combine.n
echo "======= barrier1.slk ======"
../../sleek barrier1.slk | grep Entail > test-cases/barrier1.n
echo "======= barrier-split.slk ======"
../../sleek barrier-split.slk | grep Entail > test-cases/barrier-split.n
echo "======= barrier-combine.slk ======"
../../sleek barrier-combine.slk | grep Entail > test-cases/barrier-combine.n
echo "======= barrier-sep.slk ======"
../../sleek barrier-sep.slk | grep Entail > test-cases/barrier-sep.n
echo "======= barrier-static.slk ======"
../../sleek barrier-static.slk | grep Entail > test-cases/barrier-static.n
echo "======= barrier-dynamic.slk ======"
../../sleek barrier-dynamic.slk | grep Entail > test-cases/barrier-dynamic.n
#================HIP==========================
#================HIP==========================
echo "======= hip-bperm1.ss ======"
../../hip hip-bperm1.ss | grep -E 'Proc|assert:' > test-cases/hip-bperm1.n
echo "======= bperm-exp.ss ======"
../../hip bperm-exp.ss | grep -E 'Proc|assert:' > test-cases/bperm-exp.n
echo "======= barrier-static-primitives.ss ======"
../../hip barrier-static-primitives.ss | grep -E 'Proc|assert:' > test-cases/barrier-static-primitives.n
echo "======= barrier-static-exp1.ss ======"
../../hip barrier-static-exp1.ss | grep -E 'Proc|assert:' > test-cases/barrier-static-exp1.n
echo "======= barrier-static-exp2.ss ======"
../../hip barrier-static-exp2.ss | grep -E 'Proc|assert:' > test-cases/barrier-static-exp2.n
echo "======= barrier-static-exp3.ss ======"
../../hip barrier-static-exp3.ss | grep -E 'Proc|assert:' > test-cases/barrier-static-exp3.n
echo "======= barrier-static-complex.ss ======"
../../hip barrier-static-complex.ss | grep -E 'Proc|assert:' > test-cases/barrier-static-complex.n
echo "======= barrier-static-complex2.ss ======"
../../hip barrier-static-complex2.ss | grep -E 'Proc|assert:' > test-cases/barrier-static-complex2.n
echo "======= barrier-static-multiple.ss ======"
../../hip barrier-static-multiple.ss | grep -E 'Proc|assert:' > test-cases/barrier-static-multiple.n
echo "======= barrier-dynamic-exp1.ss ======"
../../hip barrier-dynamic-exp1.ss | grep -E 'Proc|assert:' > test-cases/barrier-dynamic-exp1.n
echo "======= barrier-dynamic-exp2.ss ======"
../../hip barrier-dynamic-exp2.ss | grep -E 'Proc|assert:' > test-cases/barrier-dynamic-exp2.n
echo "======= barrier-dynamic-exp3.ss ======"
../../hip barrier-dynamic-exp3.ss | grep -E 'Proc|assert:' > test-cases/barrier-dynamic-exp3.n
#================BENCHMARK==========================
#================BENCHMARK==========================
echo "======= plash2/code/apps/barnes/ ======"
../../hip benchmark/our-splash2/code/apps/barnes/barnes.ss | grep -E 'Proc|assert:' > test-cases/splash2/barnes.n
echo "======= plash2/code/apps/fmm/ ======"
../../hip benchmark/our-splash2/code/apps/fmm/fmm.ss | grep -E 'Proc|assert:' > test-cases/splash2/fmm.n
echo "======= plash2/code/apps/ocean/ ======"
../../hip benchmark/our-splash2/code/apps/ocean/ocean.ss | grep -E 'Proc|assert:' > test-cases/splash2/ocean.n
echo "======= plash2/code/apps/volrend/ (slow) ======"
../../hip benchmark/our-splash2/code/apps/volrend/volrend.ss | grep -E 'Proc|assert:' > test-cases/splash2/volrend.n
