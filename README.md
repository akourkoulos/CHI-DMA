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

## DMAC ARCHITECTURE AND DESIGN
The proposed DMA serves the purpose of data transfer
between memory locations employing the CHI communication
protocol. The data transfer procedure initiates upon the
transmission of necessary instructions to the DMA. Notably,
the DMA supports concurrent capability by handling multiple
transfers simultaneously, allowing new instructions to be
accepted prior to the completion of previous transfers. This
concurrency is realized through the utilization of a BRAM,
with each of its addresses storing data associated with a
memory transfer. Thus, the only signals needed for assigning
a memory transfer to the DMA are those of a BRAM port.
To initiate a new transfer, the processor identifies an available
Descriptor (address) in the BRAM by examining its Status.
Subsequently, the appropriate transfer data is written to the
identified address. Similarly, the processor can be notified
about a finished transfer by polling the corresponding Status,
given the impracticability of utilizing the interrupt method
within this architecture due to scalability constraints.

|![alt text](https://github.com/akourkoulos/CHI-DMA/blob/main/chi-Doc-Draw/DMA%20DRAWINGS/Drawings/DMA.png)|
|:--:|
|*Fig. 1 Design of DMA*|

The basic components of the DMA as seen in Fig. above are:
- DescBRAM (BRAM) : stores transfer’s instructions
- Scheduler : schedules transfers
- main FIFO : keeps addresses for unschedued transfers
- CHI-Converter : executes the CHI-compliant transfer
- BarrelShifter : aligns data appropriately
The operation initiates with the processor assigning valid
transfer instructions to DMA’s BRAM. Concurrently, the corresponding
address pointer is written in the main system FIFO,
housing addresses of unscheduled Descriptors. Upon non-
empty state of the FIFO, the Scheduler is activated, extracting
instructions from DescBRAM based on the address pointer
indicated by the first element of the FIFO. Subsequently,
Scheduler sends the appropriate command to CHI-Converter,
and updates the FIFO, removing the first address pointer while
re-enqueue it if further transactions for the same instruction
require scheduling. This sequence iterates consistently. As
both processor and Scheduler needs to write information in
FIFO, an Arbiter ensures controlled access to it, granting
priority to the processor to prevent operational delays.
Upon receiving commands, CHI-Converter begins generating
 the appropriate CHI-compliant transactions for moving
data from one memory location to another. To finalize data
write operations, the CHI-Converter requires readjusted data
aligned with the destination. To achieve this, the BarrelShifter
module modifies received data before forwarding them to the
CHI-Converter for transaction completion. Finally, if a full
transfer is completed, CHI-Converter updates the Status of the
corresponding address in DescBRAM. However, considering
shared BRAM port usage by the Scheduler, there is a second
Arbiter for controlling the accesses, giving always priority to
CHI-Converter, so status will be updated as fast as possible.

## SIMULATION AND TESTING

To ensure the expected operation of the system, a behavioral
simulation is performed, both individually for each module
and collectively for the entire system, utilizing the Vivado
simulator (XSIM). Testbenches were meticulously crafted to
verify the individual components, designed to test module
behavior by subjecting them to diverse inputs, including corner
cases, all of which were successfully verified.  


To comprehensively evaluate the DMA’s functionality under
various conditions, we implemented two virtual units to interface
with the DMA. The first unit schedules different numbers
and types of transfers to the DMA in phases, while the second
responds to CHI requests with either parametrized or random
delays.
In the initial simulation, the virtual CHI interconnect responds
to the DMA a fixed number of cycles post each request
and provides unlimited amount of credits. This approach
allows for precise throughput and latency measurements that
are unaffected by interconnect and memory delays.
The waveform in Fig. 2 illustrates a complete small transfer
operation. Initially, the CPU assigns a transfer to the DMA
using a BRAM port. As the transfer necessitates single read
and write transactions, the DMA issues two requests in consecutive 
cycles, post a brief processing latency. Given the
simulation’s design, the data response arrives on the inbound
data channel after a consistent delay, concluding the read
transaction. In the subsequent cycle, the CompDBIDResp
response is received on the inbound response channel, enabling
the DMA to proceed the operation. With both data and DBID
responses, the engine transmits the data for writing on the
outbound data channel, finalizing both the transaction and the
entire transfer. Noteworthy, is that the activation of the valid
signal on the corresponding channel indicates the transmission
of each FLIT.


|![alt text](https://github.com/akourkoulos/CHI-DMA/blob/main/chi-Doc-Draw/DMA%20DRAWINGS/Drawings/waveform1.png)|
|:--:|
|*Fig. 2 1-Read 1-Write Transfer*|

Another transfer, which requires multiple read and write
transactions using the same simulation approach, is depicted
in waveform 3. In this case, after receiving and processing
the transfer from CPU, DMA initiates consecutive transmissions
on request channel. The read and write requests are
sent alternately, resulting in sequential responses on inbound
response and data channels, respectively. Upon receiving read
and write responses, the engine sends out the outbound data,
incrementally completing the extensive data transfer.

|![alt text](https://github.com/akourkoulos/CHI-DMA/blob/main/chi-Doc-Draw/DMA%20DRAWINGS/Drawings/waveform2.png)|
|:--:|
|*Fig. 3 Multi-Read-Write Transfer*|

## RESULTS

The
FPGA part utilized for this purpose was the Virtex UltraScale+
“xcvu37p-fsvh2892-2L-e”, as it is one of the most high-end
FPGA available. The most crucial delay within the design,
noted as the critical path, was determined to be 4.367 ns.
This, in turn, translates to a maximum operational frequency
of 228.99 MHz, forming the basis for assessing system performance.
The DMA’s latency for initiating data transfers starting
from the reception of transfer instructions remained constant
across all cases, amounting to 3 cycles × 4.367 ns = 13.1
ns. Despite this consistent latency, the throughput exhibited
variation depending on the specific scenario.
In TABLE I the summary of the performance in each
scenario can be seen.

|![alt text](https://github.com/akourkoulos/CHI-DMA/blob/main/chi-Doc-Draw/DMA%20DRAWINGS/Drawings/performance.png)|
|:--:|
|*TABLE I Performance*|

The synthesis tool provides valuable insights into the resource
utilization expected from the RTL design, depending
on the specific FPGA employed. Table II outlines both the
resource demands of the DMA and offers a rough breakdown
of utilization contributions from individual modules.

|![alt text](https://github.com/akourkoulos/CHI-DMA/blob/main/chi-Doc-Draw/DMA%20DRAWINGS/Drawings/utilization.png)|
|:--:|
|*TABLE II Utilization*|
