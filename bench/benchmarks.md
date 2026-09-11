# Benchmark methodology

Run the suite from the repository root:

```sh
mix deps.get
mix bench
mix docs --warnings-as-errors
```

`bench/generation.exs` uses Benchee and its Markdown formatter as development-only
dependencies. It replaces the former `scripts/benchmark_generation.exs` timer.
The generated reports live in `bench/output/`, are committed with the benchmark
source, and appear in ExDoc's **Benchmarks** group:

- [Path registration](output/paths.md): compare repeated calls to the retained
  incremental API with indexed bulk registration at 100, 500, 1,000, and 2,000 paths.
- [Schema reference checks](output/references.md): measure the current validator
  against the same counts of distinct local component references. This measures
  scaling of the current implementation; it does not recreate a historical validator.
- [YAML export](output/yaml.md): compare a JSON encode/decode round trip followed by
  YAML encoding with direct encoding of an already normalized specification, at
  100, 500, and 1,000 component schemas.

Inputs, normalization, and correctness assertions run before timing. Both path
registration jobs must return type-strictly equal results. Both YAML jobs must
produce identical bytes, and decoded YAML must preserve the normalized JSON values.
Reference fixtures include distinct resolvable targets and a rejected missing target.
There are no timing thresholds in the test suite.

Every scenario uses one worker, two seconds of warmup, five seconds of runtime
measurement, one second of memory measurement, and one second of reduction
measurement. These settings are explicit in the script. Run benchmarks without
concurrent builds, tests, or other heavy work. Slow scenarios may collect only a
few samples in that window; increase the measurement durations before drawing
fine-grained conclusions. Large deviations should be investigated, not hidden by
removing outliers.

The reports record the run time, tool versions, host information, and measurement
configuration. Benchee's memory result measures allocation in the benchmarked
process, including allocations subsequently collected. It is **not peak resident
memory** and does not include allocations made by other processes. Reductions
are BEAM work counters and can vary across runtime versions. See
[Benchee's measurement documentation](https://benchee.hexdocs.pm/readme.html#metrics-to-measure).

These are synthetic microbenchmarks of selected generation and export operations.
They do not measure HTTP throughput, full application generation, cache contention,
or all Ash resource shapes. Compare results on the same machine and runtime with
matching inputs and settings; recorded measurements are observations, not guarantees.
