## Introduction 
This work presents a comprehensive design of the architectural 
elements of a CHI-compliant DMA engine in the form
of an IP core. The engine is capable to efficiently move data
between memory locations, achieving maximum throughput in
the majority of scenarios, thereby elevating the performance of
systems that integrate it. The DMA controller is designed as an
IO Coherent node -in CHI nomenclature- and communicates
through the AMBA 5 CHI protocol, exploiting the cache-
coherence feature of CHI which improves memory access
time. The engine’s architecture is meticulously realized using
the SystemVerilog Hardware Description Language (HDL) and
its functionality is validated through thorough behavioral simulations.
Importantly, the proposed engine has been designed to
be generic and parameterized, to allow effortless adjustments
to the acceptable number of transfers or scheduling chunk size
to align with specific application requirements. Moreover, it
consolidates all communication logic within a single module,
ensuring easy replacement in case a newer protocol surpasses
CHI due to technological advancements, maintaining the rest
of the design. The throughput and latency, which are independent
of interconnection or memory delays, are measured
with the use of behavioral simulation. We also proceed to
synthesizing the design using Xiling/AMD FPGA tool flow,
collecting useful utilization information, i.e. hardware resource
demands, resulting in 14262 LUTS 33693 CLB registers and
a maximum frequency of 228 MHz. These results demonstrate
efficient resource utilization and high operation speed in this
demanding implementation.
