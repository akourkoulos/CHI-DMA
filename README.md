## Introduction 
A Direct Memory Access (DMA) feature enables
devices to efficiently transfer data to and from main memory
without involving the central processing unit (CPU). This bypass-
ing capability is particularly beneficial for handling substantial
data volumes, allowing the CPU to focus on other tasks. This
paper focuses on the meticulous HDL design, optimization, and
verification of an Intellectual Property Core (IP Core) DMA
engine, that complies with the AMBA 5 Coherent Hub Interface
(CHI) protocol. This DMA controller is designed to be able to
handle a parametrizable amount of memory transfers, generically
schedule them to meet user requirements and transfer the
appropriate data at any address byte offset in memory. Since
it is designed to operate with systems employing AMBA 5 CHI
architecture, it can utilize the benefits offered by CHI as well as
the features of the DMA architecture, and thus can prove a useful
tool for modern state-of-the-art systems. This paper presents a
comprehensive demonstration of the investigated design which
is meticulously implemented and optimized in SystemVerilog
HDL. Rigorous testing and performance analysis have confirmed
its great achievement of high speed and resource utilization
efficiency
