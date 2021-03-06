#create a list of new results
echo "======= cell.ss ======"
../../../hip cell.ss | grep -E 'Proc|assert|Warning' > test-cases/cell.n
echo "======= cell4.ss ======"
../../../hip cell4.ss | grep -E 'Proc|assert|Warning' > test-cases/cell4.n
echo "======= cell-lock-vperm.ss ======"
../../../hip cell-lock-vperm.ss | grep -E 'Proc|assert|Warning' > test-cases/cell-lock-vperm.n
echo "======= cell-extreme-cases.ss ======"
../../../hip cell-extreme-cases.ss | grep -E 'Proc|assert|Warning' > test-cases/cell-extreme-cases.n
echo "======= ls-bind.ss ======"
../../../hip ls-bind.ss | grep -E 'Proc|assert' > test-cases/ls-bind.n

########### MOST IMPORTANT (rules + examples) ####################
echo "======= cell-w-ls.ss ======"
../../../hip cell-w-ls.ss | grep -E 'Proc|assert|Warning' > test-cases/cell-w-ls.n
echo "======= multicast.ss ======"
../../../hip multicast.ss | grep -E 'Proc|assert|Warning' > test-cases/multicast.n
echo "======= oracle-esop08.ss ======"
../../../hip oracle-esop08.ss | grep -E 'Proc|assert|Warning' > test-cases/oracle-esop08.n
echo "======= owicki-gries.ss ======"
../../../hip owicki-gries.ss | grep -E 'Proc|assert|Warning' > test-cases/owicki-gries.n
########### Example of verifying deadlock freedom ####################
echo "======= ls-deadlock1.ss ======"
../../../hip ls-deadlock1.ss | grep -E 'Proc|assert|Warning' > test-cases/ls-deadlock1.n
echo "======= ls-deadlock2.ss ======"
../../../hip ls-deadlock2.ss | grep -E 'Proc|assert|Warning' > test-cases/ls-deadlock2.n
echo "======= ls-deadlock3.ss ======"
../../../hip ls-deadlock3.ss | grep -E 'Proc|assert|Warning' > test-cases/ls-deadlock3.n
echo "======= ls-double-acquisition.ss ======"
../../../hip ls-double-acquisition.ss | grep -E 'Proc|assert|Warning' > test-cases/ls-double-acquisition.n

echo "======= ls-no-deadlock1.ss ======"
../../../hip ls-no-deadlock1.ss | grep -E 'Proc|assert|Warning' > test-cases/ls-no-deadlock1.n
echo "======= ls-no-deadlock2.ss ======"
../../../hip ls-no-deadlock2.ss | grep -E 'Proc|assert|Warning' > test-cases/ls-no-deadlock2.n
echo "======= ls-no-deadlock3.ss ======"
../../../hip ls-no-deadlock3.ss | grep -E 'Proc|assert|Warning' > test-cases/ls-no-deadlock3.n

######## Example of verifying deadlock freedom with disjunction########
echo "======= ls-disj-deadlock.ss ======"
../../../hip ls-disj-deadlock.ss | grep -E 'Proc|assert|Warning' > test-cases/ls-disj-deadlock.n

echo "======= ls-disj-no-deadlock.ss ======"
../../../hip ls-disj-no-deadlock.ss | grep -E 'Proc|assert|Warning' > test-cases/ls-disj-no-deadlock.n
echo "======= ls-disj-no-deadlock2.ss ======"
../../../hip ls-disj-no-deadlock2.ss | grep -E 'Proc|assert|Warning' > test-cases/ls-disj-no-deadlock2.n
echo "======= ls-disj-no-deadlock3.ss ======"
../../../hip ls-disj-no-deadlock3.ss | grep -E 'Proc|assert|Warning' > test-cases/ls-disj-no-deadlock3.n

########### Example demonstrating locklevels ####################
echo "======= ls-waitlevel.ss ======" #GENERAL TEST
../../../hip ls-waitlevel.ss --locklevel | grep -E 'Proc|assert|Warning' > test-cases/ls-waitlevel.n
echo "======= ls-waitlevel2.ss ======" #GENERAL TEST
../../../hip ls-waitlevel2.ss --locklevel | grep -E 'Proc|assert|Warning' > test-cases/ls-waitlevel2.n
echo "======= ls-unordered-locking.ss ======"
../../../hip ls-unordered-locking.ss --locklevel | grep -E 'Proc|assert|Warning' > test-cases/ls-unordered-locking.n
echo "======= ls-ordered-locking.ss ======"
../../../hip ls-ordered-locking.ss --locklevel | grep -E 'Proc|assert|Warning' > test-cases/ls-ordered-locking.n
