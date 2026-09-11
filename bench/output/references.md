# Schema reference checks

Measures the current validator with distinct local references and matching component targets.

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



__Input: 100 references__

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
    <td style="white-space: nowrap">validate local references</td>
    <td style="white-space: nowrap; text-align: right">5.41 K</td>
    <td style="white-space: nowrap; text-align: right">184.81 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;7.19%</td>
    <td style="white-space: nowrap; text-align: right">183.92 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">219.61 &micro;s</td>
  </tr>

</table>


Run Time Comparison

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">IPS</th>
    <th style="text-align: right">Slower</th>
  <tr>
    <td style="white-space: nowrap">validate local references</td>
    <td style="white-space: nowrap;text-align: right">5.41 K</td>
    <td>&nbsp;</td>
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
    <td style="white-space: nowrap">validate local references</td>
    <td style="white-space: nowrap">115.39 KB</td>
    <td>&nbsp;</td>
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
    <td style="white-space: nowrap">validate local references</td>
    <td style="white-space: nowrap">12.64 K</td>
    <td>&nbsp;</td>
  </tr>
</table>


__Input: 500 references__

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
    <td style="white-space: nowrap">validate local references</td>
    <td style="white-space: nowrap; text-align: right">1.26 K</td>
    <td style="white-space: nowrap; text-align: right">795.02 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;4.37%</td>
    <td style="white-space: nowrap; text-align: right">789.33 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">909.99 &micro;s</td>
  </tr>

</table>


Run Time Comparison

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">IPS</th>
    <th style="text-align: right">Slower</th>
  <tr>
    <td style="white-space: nowrap">validate local references</td>
    <td style="white-space: nowrap;text-align: right">1.26 K</td>
    <td>&nbsp;</td>
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
    <td style="white-space: nowrap">validate local references</td>
    <td style="white-space: nowrap">572.89 KB</td>
    <td>&nbsp;</td>
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
    <td style="white-space: nowrap">validate local references</td>
    <td style="white-space: nowrap">64.54 K</td>
    <td>&nbsp;</td>
  </tr>
</table>


__Input: 1000 references__

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
    <td style="white-space: nowrap">validate local references</td>
    <td style="white-space: nowrap; text-align: right">645.39</td>
    <td style="white-space: nowrap; text-align: right">1.55 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;4.22%</td>
    <td style="white-space: nowrap; text-align: right">1.53 ms</td>
    <td style="white-space: nowrap; text-align: right">1.78 ms</td>
  </tr>

</table>


Run Time Comparison

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">IPS</th>
    <th style="text-align: right">Slower</th>
  <tr>
    <td style="white-space: nowrap">validate local references</td>
    <td style="white-space: nowrap;text-align: right">645.39</td>
    <td>&nbsp;</td>
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
    <td style="white-space: nowrap">validate local references</td>
    <td style="white-space: nowrap">1.12 MB</td>
    <td>&nbsp;</td>
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
    <td style="white-space: nowrap">validate local references</td>
    <td style="white-space: nowrap">128.64 K</td>
    <td>&nbsp;</td>
  </tr>
</table>


__Input: 2000 references__

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
    <td style="white-space: nowrap">validate local references</td>
    <td style="white-space: nowrap; text-align: right">318.00</td>
    <td style="white-space: nowrap; text-align: right">3.14 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;3.65%</td>
    <td style="white-space: nowrap; text-align: right">3.11 ms</td>
    <td style="white-space: nowrap; text-align: right">3.54 ms</td>
  </tr>

</table>


Run Time Comparison

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">IPS</th>
    <th style="text-align: right">Slower</th>
  <tr>
    <td style="white-space: nowrap">validate local references</td>
    <td style="white-space: nowrap;text-align: right">318.00</td>
    <td>&nbsp;</td>
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
    <td style="white-space: nowrap">validate local references</td>
    <td style="white-space: nowrap">2.28 MB</td>
    <td>&nbsp;</td>
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
    <td style="white-space: nowrap">validate local references</td>
    <td style="white-space: nowrap">254.73 K</td>
    <td>&nbsp;</td>
  </tr>
</table>