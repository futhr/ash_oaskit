# YAML export

Compares the former JSON round trip with direct YAML encoding of normalized native values.

Recorded at 2026-09-11T08:37:50.983973Z with `mix bench`.
AshOaskit 0.4.1,
Benchee 1.5.1,
benchee_markdown 0.3.4.

Inputs and correctness checks are outside timed work. Scenarios run serially
with 2 seconds of warmup, 5 seconds of runtime measurement, 1 second of memory
measurement, and 1 second of reduction measurement. Slow scenarios may collect
few samples; these measurements are observations, not guarantees.

Memory results measure allocations in the benchmarked process, not peak resident
memory or allocations in other processes. See [methodology](../benchmarks.md).


## System

Benchmark suite executing on the following system:

<table style="width: 1%">
  <tr>
    <th style="width: 1%; white-space: nowrap">Operating System</th>
    <td>macOS</td>
  </tr><tr>
    <th style="white-space: nowrap">CPU Information</th>
    <td style="white-space: nowrap">Apple M5 Pro</td>
  </tr><tr>
    <th style="white-space: nowrap">Number of Available Cores</th>
    <td style="white-space: nowrap">18</td>
  </tr><tr>
    <th style="white-space: nowrap">Available Memory</th>
    <td style="white-space: nowrap">48 GB</td>
  </tr><tr>
    <th style="white-space: nowrap">Elixir Version</th>
    <td style="white-space: nowrap">1.20.4</td>
  </tr><tr>
    <th style="white-space: nowrap">Erlang Version</th>
    <td style="white-space: nowrap">28.5.0.6</td>
  </tr>
</table>

## Configuration

Benchmark suite executing with the following configuration:

<table style="width: 1%">
  <tr>
    <th style="width: 1%">:time</th>
    <td style="white-space: nowrap">5 s</td>
  </tr><tr>
    <th>:parallel</th>
    <td style="white-space: nowrap">1</td>
  </tr><tr>
    <th>:warmup</th>
    <td style="white-space: nowrap">2 s</td>
  </tr>
</table>

## Statistics



__Input: 100 schemas (18045 JSON bytes)__

Run Time

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">IPS</th>
    <th style="text-align: right">Average</th>
    <th style="text-align: right">Deviation</th>
    <th style="text-align: right">Median</th>
    <th style="text-align: right">99th&nbsp;%</th>
  </tr>

  <tr>
    <td style="white-space: nowrap">direct YAML</td>
    <td style="white-space: nowrap; text-align: right">4.19 K</td>
    <td style="white-space: nowrap; text-align: right">238.69 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;13.99%</td>
    <td style="white-space: nowrap; text-align: right">226.17 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">352.69 &micro;s</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">JSON round trip then YAML</td>
    <td style="white-space: nowrap; text-align: right">2.11 K</td>
    <td style="white-space: nowrap; text-align: right">474.95 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;9.50%</td>
    <td style="white-space: nowrap; text-align: right">464.71 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">602.38 &micro;s</td>
  </tr>

</table>


Run Time Comparison

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">IPS</th>
    <th style="text-align: right">Slower</th>
  <tr>
    <td style="white-space: nowrap">direct YAML</td>
    <td style="white-space: nowrap;text-align: right">4.19 K</td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">JSON round trip then YAML</td>
    <td style="white-space: nowrap; text-align: right">2.11 K</td>
    <td style="white-space: nowrap; text-align: right">1.99x</td>
  </tr>

</table>



Memory Usage

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">Average</th>
    <th style="text-align: right">Factor</th>
  </tr>
  <tr>
    <td style="white-space: nowrap">direct YAML</td>
    <td style="white-space: nowrap">574.63 KB</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">JSON round trip then YAML</td>
    <td style="white-space: nowrap">1000.88 KB</td>
    <td>1.74x</td>
  </tr>
</table>



Reduction Count

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">Average</th>
    <th style="text-align: right">Factor</th>
  </tr>
  <tr>
    <td style="white-space: nowrap">direct YAML</td>
    <td style="white-space: nowrap">85.58 K</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">JSON round trip then YAML</td>
    <td style="white-space: nowrap">141.65 K</td>
    <td>1.66x</td>
  </tr>
</table>


__Input: 500 schemas (90445 JSON bytes)__

Run Time

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">IPS</th>
    <th style="text-align: right">Average</th>
    <th style="text-align: right">Deviation</th>
    <th style="text-align: right">Median</th>
    <th style="text-align: right">99th&nbsp;%</th>
  </tr>

  <tr>
    <td style="white-space: nowrap">direct YAML</td>
    <td style="white-space: nowrap; text-align: right">832.84</td>
    <td style="white-space: nowrap; text-align: right">1.20 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;8.13%</td>
    <td style="white-space: nowrap; text-align: right">1.16 ms</td>
    <td style="white-space: nowrap; text-align: right">1.47 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">JSON round trip then YAML</td>
    <td style="white-space: nowrap; text-align: right">420.46</td>
    <td style="white-space: nowrap; text-align: right">2.38 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;6.38%</td>
    <td style="white-space: nowrap; text-align: right">2.37 ms</td>
    <td style="white-space: nowrap; text-align: right">2.79 ms</td>
  </tr>

</table>


Run Time Comparison

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">IPS</th>
    <th style="text-align: right">Slower</th>
  <tr>
    <td style="white-space: nowrap">direct YAML</td>
    <td style="white-space: nowrap;text-align: right">832.84</td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">JSON round trip then YAML</td>
    <td style="white-space: nowrap; text-align: right">420.46</td>
    <td style="white-space: nowrap; text-align: right">1.98x</td>
  </tr>

</table>



Memory Usage

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">Average</th>
    <th style="text-align: right">Factor</th>
  </tr>
  <tr>
    <td style="white-space: nowrap">direct YAML</td>
    <td style="white-space: nowrap">2.79 MB</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">JSON round trip then YAML</td>
    <td style="white-space: nowrap">4.85 MB</td>
    <td>1.74x</td>
  </tr>
</table>



Reduction Count

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">Average</th>
    <th style="text-align: right">Factor</th>
  </tr>
  <tr>
    <td style="white-space: nowrap">direct YAML</td>
    <td style="white-space: nowrap">416.18 K</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">JSON round trip then YAML</td>
    <td style="white-space: nowrap">690.23 K</td>
    <td>1.66x</td>
  </tr>
</table>


__Input: 1000 schemas (180947 JSON bytes)__

Run Time

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">IPS</th>
    <th style="text-align: right">Average</th>
    <th style="text-align: right">Deviation</th>
    <th style="text-align: right">Median</th>
    <th style="text-align: right">99th&nbsp;%</th>
  </tr>

  <tr>
    <td style="white-space: nowrap">direct YAML</td>
    <td style="white-space: nowrap; text-align: right">387.82</td>
    <td style="white-space: nowrap; text-align: right">2.58 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;8.02%</td>
    <td style="white-space: nowrap; text-align: right">2.52 ms</td>
    <td style="white-space: nowrap; text-align: right">3.12 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">JSON round trip then YAML</td>
    <td style="white-space: nowrap; text-align: right">199.77</td>
    <td style="white-space: nowrap; text-align: right">5.01 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;3.54%</td>
    <td style="white-space: nowrap; text-align: right">4.98 ms</td>
    <td style="white-space: nowrap; text-align: right">5.56 ms</td>
  </tr>

</table>


Run Time Comparison

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">IPS</th>
    <th style="text-align: right">Slower</th>
  <tr>
    <td style="white-space: nowrap">direct YAML</td>
    <td style="white-space: nowrap;text-align: right">387.82</td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">JSON round trip then YAML</td>
    <td style="white-space: nowrap; text-align: right">199.77</td>
    <td style="white-space: nowrap; text-align: right">1.94x</td>
  </tr>

</table>



Memory Usage

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">Average</th>
    <th style="text-align: right">Factor</th>
  </tr>
  <tr>
    <td style="white-space: nowrap">direct YAML</td>
    <td style="white-space: nowrap">5.57 MB</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">JSON round trip then YAML</td>
    <td style="white-space: nowrap">9.69 MB</td>
    <td>1.74x</td>
  </tr>
</table>



Reduction Count

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">Average</th>
    <th style="text-align: right">Factor</th>
  </tr>
  <tr>
    <td style="white-space: nowrap">direct YAML</td>
    <td style="white-space: nowrap">0.82 M</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">JSON round trip then YAML</td>
    <td style="white-space: nowrap">1.36 M</td>
    <td>1.66x</td>
  </tr>
</table>