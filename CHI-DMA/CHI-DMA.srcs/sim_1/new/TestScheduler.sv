`timescale 1ns / 1ps
`include "RSParameters.vh"
import CHIFIFOsPkg ::*; 
import DataPkg::*; 
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 14.07.2022 18:55:18
// Design Name: 
// Module Name: TestScheduler
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module TestScheduler#(
  parameter BRAM_ADDR_WIDTH   = 10 ,
  parameter BRAM_NUM_COL      = 8  , // num of Reg in Descriptor
  parameter BRAM_COL_WIDTH    = 32 , // width of a Reg in Descriptor 
  parameter CHI_DATA_WIDTH    = 64 ,  
  parameter Chunk             = 5  , // number of CHI-Words
  parameter MEMAddrWidth      = 32   
 );
    reg                                RST               ;                               
    reg                                Clk               ;                               
    Data_packet                        DescDataIn        ; //sig from BRAM               
    reg                                ReadyBRAM         ; //sig from BRAM's Arbiter     
    reg                                ReadyFIFO         ; //sig from FIFO's Arbiter     
    reg        [BRAM_ADDR_WIDTH  -1:0] FIFO_Addr         ; //sig from FIFO               
    reg                                Empty             ;                               
    reg                                CmdFIFOFULL       ; //sig from chi-converter      
    Data_packet                        DescDataOut       ; //sig for BRAM                
    wire       [BRAM_NUM_COL     -1:0] WE                ;                               
    wire       [BRAM_ADDR_WIDTH  -1:0] BRAMAddrOut       ;                               
    wire                               ValidBRAM         ; //sig for BRAM's Arbiter      
    wire                               Dequeue           ; //sig for FIFO                
    wire                               ValidFIFO         ; //sig for FIFO 's Arbiter     
    wire       [BRAM_ADDR_WIDTH  -1:0] DescAddrPointer   ;                               
    wire                               IssueValid        ; //sig for chi-converter       
    CHI_Command                        Command           ;                             
    
    // duration for each bit = 20 * timescale = 20 * 1 ns  = 20ns
    localparam period = 20;  

    Scheduler UUT (
    .RST              (RST              ) ,
    .Clk              (Clk              ) ,
    .DescDataIn       (DescDataIn       ) ,
    .ReadyBRAM        (ReadyBRAM        ) ,
    .ReadyFIFO        (ReadyFIFO        ) ,
    .FIFO_Addr        (FIFO_Addr        ) ,
    .Empty            (Empty            ) ,
    .CmdFIFOFULL      (CmdFIFOFULL      ) ,
    .DescDataOut      (DescDataOut      ) ,
    .WE               (WE               ) , 
    .BRAMAddrOut      (BRAMAddrOut      ) ,
    .ValidBRAM        (ValidBRAM        ) ,
    .Dequeue          (Dequeue          ) ,
    .ValidFIFO        (ValidFIFO        ) ,
    .DescAddrPointer  (DescAddrPointer  ) ,
    .IssueValid       (IssueValid       ) ,
    .Command          (Command          ) 
    );
    
    always 
    begin
        Clk = 1'b1; 
        #20; // high for 20 * timescale = 20 ns
    
        Clk = 1'b0;
        #20; // low for 20 * timescale = 20 ns
    end
    

    always @(posedge Clk)
        begin
         // Reset 
         RST           = 1              ;       
         DescDataIn    = 'd10           ;
         ReadyBRAM     = 1              ;    
         ReadyFIFO     = 0              ;     
         FIFO_Addr     = 0              ;     
         Empty         = 1              ;       
         CmdFIFOFULL   = 0              ;
        
        #(period*2); // wait for period begin
        #period   // signals change at the negedge of Clk
        //(Idle State)FIFO Empty
         RST                    = 0              ;       
         DescDataIn.SrcAddr     = 0              ;
         DescDataIn.DstAddr     = 0              ;
         DescDataIn.BytesToSend = 0              ;
         DescDataIn.SentBytes   = 0              ; 
         DescDataIn.Status      = 0              ;
         ReadyBRAM              = 0              ;    
         ReadyFIFO              = 0              ;     
         FIFO_Addr              = 0              ;     
         Empty                  = 1              ;       
         CmdFIFOFULL            = 0              ;
         
         #(period*2); // wait for period begin
         //(Idle State)No access to BRAM
         RST                    = 0              ;       
         DescDataIn.SrcAddr     = 0              ;
         DescDataIn.DstAddr     = 0              ;
         DescDataIn.BytesToSend = 0              ;
         DescDataIn.SentBytes   = 0              ; 
         DescDataIn.Status      = 0              ;
         ReadyBRAM              = 0              ;    
         ReadyFIFO              = 0              ;     
         FIFO_Addr              = 'd2            ;     
         Empty                  = 0              ;       
         CmdFIFOFULL            = 0              ;
         
         #(period*2); // wait for period begin
         //(Idle State)Read from BRAM
         RST                    = 0              ;       
         DescDataIn.SrcAddr     = 0              ;
         DescDataIn.DstAddr     = 0              ;
         DescDataIn.BytesToSend = 0              ;
         DescDataIn.SentBytes   = 0              ; 
         DescDataIn.Status      = 0              ;
         ReadyBRAM              = 1              ;    
         ReadyFIFO              = 0              ;     
         FIFO_Addr              = 'd2            ;     
         Empty                  = 0              ;       
         CmdFIFOFULL            = 0              ;
         
         #(period*2); // wait for period begin
        //(Issue State) No Access to BRAM
         RST                    = 0              ;       
         DescDataIn.SrcAddr     = 'd10           ;
         DescDataIn.DstAddr     = 'd1000         ;
         DescDataIn.BytesToSend = 'd700          ;
         DescDataIn.SentBytes   = 'd0            ; // BTS-SD > chunk*CHI_WORD
         DescDataIn.Status      = 'd1            ;
         ReadyBRAM              = 0              ;    
         ReadyFIFO              = 0              ;     
         FIFO_Addr              = 'd2            ;     
         Empty                  = 0              ;       
         CmdFIFOFULL            = 0              ;
      
        #(period*2); // wait for period begin
         //(Idle State)Read from BRAM access regained
         RST                    = 0              ;       
         DescDataIn.SrcAddr     = 0              ;
         DescDataIn.DstAddr     = 0              ;
         DescDataIn.BytesToSend = 0              ;
         DescDataIn.SentBytes   = 0              ; 
         DescDataIn.Status      = 0              ;
         ReadyBRAM              = 1              ;    
         ReadyFIFO              = 0              ;     
         FIFO_Addr              = 'd2            ;     
         Empty                  = 0              ;       
         CmdFIFOFULL            = 0              ;
         
         #(period*2); // wait for period begin
        //(Issue State) issue command
         RST                    = 0              ;       
         DescDataIn.SrcAddr     = 'd10           ;
         DescDataIn.DstAddr     = 'd1000         ;
         DescDataIn.BytesToSend = 'd700          ;
         DescDataIn.SentBytes   = 'd0            ; // BTS-SD > chunk*CHI_WORD
         DescDataIn.Status      = 'd1            ;
         ReadyBRAM              = 1              ;    
         ReadyFIFO              = 0              ;     
         FIFO_Addr              = 'd2            ;     
         Empty                  = 0              ;       
         CmdFIFOFULL            = 0              ;
         
         #(period*2); // wait for period begin
        //(WriteBack State) issue command
         RST                    = 0              ;       
         DescDataIn.SrcAddr     = 'd10           ;
         DescDataIn.DstAddr     = 'd1000         ;
         DescDataIn.BytesToSend = 'd700          ;
         DescDataIn.SentBytes   = 'd0            ; 
         DescDataIn.Status      = 'd1            ;
         ReadyBRAM              = 0              ;    
         ReadyFIFO              = 1              ;     
         FIFO_Addr              = 'd3            ;     
         Empty                  = 0              ;       
         CmdFIFOFULL            = 0              ;
         
        #(period*2); // wait for period begin
        //(Idle State) Read next Descripotr 
         RST                    = 0              ;       
         DescDataIn.SrcAddr     = 'd0            ;
         DescDataIn.DstAddr     = 'd0            ;
         DescDataIn.BytesToSend = 'd0            ;
         DescDataIn.SentBytes   = 'd0            ; 
         DescDataIn.Status      = 'd0            ;
         ReadyBRAM              = 1              ;    
         ReadyFIFO              = 0              ;     
         FIFO_Addr              = 'd3            ;     
         Empty                  = 0              ;       
         CmdFIFOFULL            = 0              ;
      
        #(period*2); // wait for period begin
         // (Issue State) Comand FIFO FULL -> wait
         RST                    = 0              ;       
         DescDataIn.SrcAddr     = 'd10           ;
         DescDataIn.DstAddr     = 'd600          ;
         DescDataIn.BytesToSend = 'd200          ;
         DescDataIn.SentBytes   = 'd0            ; // BTS-SD < chunk*CHI_WORD
         DescDataIn.Status      = 'd0            ;
         ReadyBRAM              = 1              ;    
         ReadyFIFO              = 0              ;     
         FIFO_Addr              = 'd3            ;     
         Empty                  = 0              ;       
         CmdFIFOFULL            = 1              ;
         
         #(period*2); // wait for period begin
         // (Issue State) Schedule FULL Desc
         RST                    = 0              ;       
         DescDataIn.SrcAddr     = 'd10           ;
         DescDataIn.DstAddr     = 'd600          ;
         DescDataIn.BytesToSend = 'd200          ;
         DescDataIn.SentBytes   = 'd0            ; // BTS-SD < chunk*CHI_WORD
         DescDataIn.Status      = 'd0            ;
         ReadyBRAM              = 1              ;    
         ReadyFIFO              = 0              ;     
         FIFO_Addr              = 'd3            ;     
         Empty                  = 0              ;       
         CmdFIFOFULL            = 0              ;
         
         #(period*2); // wait for period begin
         // (Idle State) Read Next Desc beacus last is finished
         RST                    = 0              ;       
         DescDataIn.SrcAddr     = 'd10           ;
         DescDataIn.DstAddr     = 'd600          ;
         DescDataIn.BytesToSend = 'd200          ;
         DescDataIn.SentBytes   = 'd0            ; // BTS-SD < chunk*CHI_WORD
         DescDataIn.Status      = 'd0            ;
         ReadyBRAM              = 1              ;    
         ReadyFIFO              = 0              ;     
         FIFO_Addr              = 'd2            ;     
         Empty                  = 0              ;       
         CmdFIFOFULL            = 0              ;
         
         #(period*2); // wait for period begin
        //(Issue State) issue command
         RST                    = 0                         ;       
         DescDataIn.SrcAddr     = 'd10                      ;
         DescDataIn.DstAddr     = 'd1000                    ;
         DescDataIn.BytesToSend = 'd700                     ;
         DescDataIn.SentBytes   = Chunk*CHI_DATA_WIDTH - 10 ; // BTS-SD > chunk*CHI_WORD
         DescDataIn.Status      = 'd1                       ;
         ReadyBRAM              = 1                         ;    
         ReadyFIFO              = 0                         ;     
         FIFO_Addr              = 'd2                       ;     
         Empty                  = 0                         ;       
         CmdFIFOFULL            = 0                         ;
         
         #(period*2); // wait for period begin
         // (WriteBack State) no access to FIFO
         RST                    = 0                         ;       
         DescDataIn.SrcAddr     = 'd10                      ;
         DescDataIn.DstAddr     = 'd1000                    ;
         DescDataIn.BytesToSend = 'd700                     ;
         DescDataIn.SentBytes   = Chunk*CHI_DATA_WIDTH - 10 ; 
         DescDataIn.Status      = 'd1                       ;
         ReadyBRAM              = 1                         ;    
         ReadyFIFO              = 0                         ;     
         FIFO_Addr              = 'd0                       ;     
         Empty                  = 1                         ;       
         CmdFIFOFULL            = 0                         ;
         
         #(period*2); // wait for period begin
         // (WriteBack State) FIFO Empty Read and write last pointer
         RST                    = 0                                 ;       
         DescDataIn.SrcAddr     = 'd10                              ;
         DescDataIn.DstAddr     = 'd1000                            ;
         DescDataIn.BytesToSend = 'd700                             ;
         DescDataIn.SentBytes   = Chunk*CHI_DATA_WIDTH - 10         ; 
         DescDataIn.Status      = 'd1                               ;
         ReadyBRAM              = 1                                 ;    
         ReadyFIFO              = 1                                 ;     
         FIFO_Addr              = 'd0                               ;     
         Empty                  = 1                                 ;       
         CmdFIFOFULL            = 0                                 ;
      
        #(period*2); // wait for period begin
         // (Issue State) schedule last transaction
         RST                    = 0                                ;       
         DescDataIn.SrcAddr     = 'd10                             ;
         DescDataIn.DstAddr     = 'd1000                           ;
         DescDataIn.BytesToSend = 'd700                            ;
         DescDataIn.SentBytes   = 2* Chunk*CHI_DATA_WIDTH - 10     ; // BTS-SD < chunk*CHI_WORD
         DescDataIn.Status      = 'd1                              ;
         ReadyBRAM              = 1                                ;    
         ReadyFIFO              = 0                                ;     
         FIFO_Addr              = 'd2                              ;     
         Empty                  = 0                                ;       
         CmdFIFOFULL            = 0                                ;
      
        #(period*2); // wait for period begin
        // (Idle State) 
         RST                    = 0              ;       
         DescDataIn.SrcAddr     = 'd0            ;
         DescDataIn.DstAddr     = 'd0            ;
         DescDataIn.BytesToSend = 'd0            ;
         DescDataIn.SentBytes   = 'd0            ; 
         DescDataIn.Status      = 'd0            ;
         ReadyBRAM              = 1              ;    
         ReadyFIFO              = 0              ;     
         FIFO_Addr              = 'd0            ;     
         Empty                  = 1              ;       
         CmdFIFOFULL            = 0              ;
        
        #(period*2); // wait for period begin
        // (Idle State) new transfer to read
         RST                    = 0              ;       
         DescDataIn.SrcAddr     = 'd0            ;
         DescDataIn.DstAddr     = 'd0            ;
         DescDataIn.BytesToSend = 'd0            ;
         DescDataIn.SentBytes   = 'd0            ; 
         DescDataIn.Status      = 'd0            ;
         ReadyBRAM              = 1              ;    
         ReadyFIFO              = 0              ;     
         FIFO_Addr              = 'd1            ;     
         Empty                  = 0              ;       
         CmdFIFOFULL            = 0              ;
      
        
        #(period*2); // wait for period begin
        // (Issue State) Empty transfer
         RST                    = 0              ;       
         DescDataIn.SrcAddr     = 'd10           ;
         DescDataIn.DstAddr     = 'd1000         ;
         DescDataIn.BytesToSend = 'd0            ;
         DescDataIn.SentBytes   = 'd0            ; 
         DescDataIn.Status      = 'd0            ;
         ReadyBRAM              = 1              ;    
         ReadyFIFO              = 0              ;     
         FIFO_Addr              = 'd1            ;     
         Empty                  = 0              ;       
         CmdFIFOFULL            = 0              ;
      
        #(period*2); // wait for period begin
        // (Idle State) End
         RST                    = 0              ;       
         DescDataIn.SrcAddr     = 'd0            ;
         DescDataIn.DstAddr     = 'd0            ;
         DescDataIn.BytesToSend = 'd0            ;
         DescDataIn.SentBytes   = 'd0            ; 
         DescDataIn.Status      = 'd0            ;
         ReadyBRAM              = 1              ;    
         ReadyFIFO              = 0              ;     
         FIFO_Addr              = 'd0            ;     
         Empty                  = 1              ;       
         CmdFIFOFULL            = 0              ;
        #(period*2); // wait for period begin
        $stop;
        end
    
  
  
endmodule

