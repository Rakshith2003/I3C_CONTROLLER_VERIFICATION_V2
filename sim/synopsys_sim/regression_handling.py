# -*- coding: utf-8 -*-
import os
import sys

if len(sys.argv) < 2:
    print("Usage: python regression_handling.py <testlist> [num_seeds]")
    sys.exit(1)

testlist = sys.argv[1]
num_seeds = int(sys.argv[2]) if len(sys.argv) > 2 else 10

if not os.path.isfile(testlist):
    print("Error: Test list file '{}' not found".format(testlist))
    sys.exit(1)

if num_seeds < 1:
    print("Error: num_seeds must be at least 1")
    sys.exit(1)

with open(testlist, 'r') as f:
    tests = [
        line.strip()
        for line in f
        if line.strip() and not line.lstrip().startswith("#")
    ]

if not tests:
    print("Error: No tests found in '{}'".format(testlist))
    sys.exit(1)

passed = []
failed = []

for test in tests:
    print("\n========================================")
    print("Running test: {}".format(test))
    print("========================================")

    for seed in range(1, num_seeds + 1):
        folder = "{}_seed{}".format(test, seed)

        print("  Seed {:3d} -> folder: {}".format(seed, folder))

        cmd = (
            "make simulate test={} seed={} test_folder={}"
            .format(test, seed, folder)
        )

        ret = os.system(cmd)

        if ret != 0:
            print("  *** FAILED: {} (seed={}) ***".format(test, seed))
            failed.append((test, seed))
        else:
            print("  PASSED: {} (seed={})".format(test, seed))
            passed.append((test, seed))

total = len(passed) + len(failed)

print("\n")
print("=" * 60)
print("REGRESSION SUMMARY")
print("=" * 60)
print("Total runs : {}".format(total))
print("Passed     : {}".format(len(passed)))
print("Failed     : {}".format(len(failed)))

if failed:
    print("\nFailed runs:")
    for test, seed in failed:
        print("  {} seed={}".format(test, seed))

print("=" * 60)
print("\nCoverage merge will be done by: make merge_cov_report")
print("VCS coverage databases: *_seed*/*.vdb")

if failed:
    sys.exit(1)
