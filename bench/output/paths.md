# Path registration

Compares the retained incremental API with indexed bulk generation using identical operations.

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



__Input: 100 paths__

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
    <td style="white-space: nowrap">indexed registration</td>
    <td style="white-space: nowrap; text-align: right">6.47 K</td>
    <td style="white-space: nowrap; text-align: right">0.154 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;6.55%</td>
    <td style="white-space: nowrap; text-align: right">0.153 ms</td>
    <td style="white-space: nowrap; text-align: right">0.190 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">incremental registration</td>
    <td style="white-space: nowrap; text-align: right">0.149 K</td>
    <td style="white-space: nowrap; text-align: right">6.72 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;1.62%</td>
    <td style="white-space: nowrap; text-align: right">6.71 ms</td>
    <td style="white-space: nowrap; text-align: right">6.96 ms</td>
  </tr>

</table>


Run Time Comparison

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">IPS</th>
    <th style="text-align: right">Slower</th>
  <tr>
    <td style="white-space: nowrap">indexed registration</td>
    <td style="white-space: nowrap;text-align: right">6.47 K</td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">incremental registration</td>
    <td style="white-space: nowrap; text-align: right">0.149 K</td>
    <td style="white-space: nowrap; text-align: right">43.47x</td>
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
    <td style="white-space: nowrap">indexed registration</td>
    <td style="white-space: nowrap">0.185 MB</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">incremental registration</td>
    <td style="white-space: nowrap">6.61 MB</td>
    <td>35.67x</td>
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
    <td style="white-space: nowrap">indexed registration</td>
    <td style="white-space: nowrap">11.20 K</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">incremental registration</td>
    <td style="white-space: nowrap">499.22 K</td>
    <td>44.57x</td>
  </tr>
</table>


__Input: 500 paths__

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
    <td style="white-space: nowrap">indexed registration</td>
    <td style="white-space: nowrap; text-align: right">1.24 K</td>
    <td style="white-space: nowrap; text-align: right">0.80 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;4.54%</td>
    <td style="white-space: nowrap; text-align: right">0.79 ms</td>
    <td style="white-space: nowrap; text-align: right">0.91 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">incremental registration</td>
    <td style="white-space: nowrap; text-align: right">0.00611 K</td>
    <td style="white-space: nowrap; text-align: right">163.65 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;0.79%</td>
    <td style="white-space: nowrap; text-align: right">163.18 ms</td>
    <td style="white-space: nowrap; text-align: right">168.58 ms</td>
  </tr>

</table>


Run Time Comparison

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">IPS</th>
    <th style="text-align: right">Slower</th>
  <tr>
    <td style="white-space: nowrap">indexed registration</td>
    <td style="white-space: nowrap;text-align: right">1.24 K</td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">incremental registration</td>
    <td style="white-space: nowrap; text-align: right">0.00611 K</td>
    <td style="white-space: nowrap; text-align: right">203.74x</td>
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
    <td style="white-space: nowrap">indexed registration</td>
    <td style="white-space: nowrap">0.95 MB</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">incremental registration</td>
    <td style="white-space: nowrap">163.37 MB</td>
    <td>171.7x</td>
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
    <td style="white-space: nowrap">indexed registration</td>
    <td style="white-space: nowrap">0.0579 M</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">incremental registration</td>
    <td style="white-space: nowrap">12.35 M</td>
    <td>213.39x</td>
  </tr>
</table>


__Input: 1000 paths__

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
    <td style="white-space: nowrap">indexed registration</td>
    <td style="white-space: nowrap; text-align: right">614.30</td>
    <td style="white-space: nowrap; text-align: right">1.63 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;5.04%</td>
    <td style="white-space: nowrap; text-align: right">1.61 ms</td>
    <td style="white-space: nowrap; text-align: right">1.85 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">incremental registration</td>
    <td style="white-space: nowrap; text-align: right">1.49</td>
    <td style="white-space: nowrap; text-align: right">670.04 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;0.49%</td>
    <td style="white-space: nowrap; text-align: right">670.02 ms</td>
    <td style="white-space: nowrap; text-align: right">674.81 ms</td>
  </tr>

</table>


Run Time Comparison

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">IPS</th>
    <th style="text-align: right">Slower</th>
  <tr>
    <td style="white-space: nowrap">indexed registration</td>
    <td style="white-space: nowrap;text-align: right">614.30</td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">incremental registration</td>
    <td style="white-space: nowrap; text-align: right">1.49</td>
    <td style="white-space: nowrap; text-align: right">411.61x</td>
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
    <td style="white-space: nowrap">indexed registration</td>
    <td style="white-space: nowrap">1.96 MB</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">incremental registration</td>
    <td style="white-space: nowrap">652.62 MB</td>
    <td>332.67x</td>
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
    <td style="white-space: nowrap">indexed registration</td>
    <td style="white-space: nowrap">0.118 M</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">incremental registration</td>
    <td style="white-space: nowrap">49.36 M</td>
    <td>416.58x</td>
  </tr>
</table>


__Input: 2000 paths__

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
    <td style="white-space: nowrap">indexed registration</td>
    <td style="white-space: nowrap; text-align: right">305.39</td>
    <td style="white-space: nowrap; text-align: right">0.00327 s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;4.47%</td>
    <td style="white-space: nowrap; text-align: right">0.00321 s</td>
    <td style="white-space: nowrap; text-align: right">0.00361 s</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">incremental registration</td>
    <td style="white-space: nowrap; text-align: right">0.38</td>
    <td style="white-space: nowrap; text-align: right">2.60 s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;0.07%</td>
    <td style="white-space: nowrap; text-align: right">2.60 s</td>
    <td style="white-space: nowrap; text-align: right">2.60 s</td>
  </tr>

</table>


Run Time Comparison

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">IPS</th>
    <th style="text-align: right">Slower</th>
  <tr>
    <td style="white-space: nowrap">indexed registration</td>
    <td style="white-space: nowrap;text-align: right">305.39</td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">incremental registration</td>
    <td style="white-space: nowrap; text-align: right">0.38</td>
    <td style="white-space: nowrap; text-align: right">794.92x</td>
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
    <td style="white-space: nowrap">indexed registration</td>
    <td style="white-space: nowrap">0.00394 GB</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">incremental registration</td>
    <td style="white-space: nowrap">2.55 GB</td>
    <td>645.82x</td>
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
    <td style="white-space: nowrap">indexed registration</td>
    <td style="white-space: nowrap">0.23 M</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">incremental registration</td>
    <td style="white-space: nowrap">197.10 M</td>
    <td>865.94x</td>
  </tr>
</table>