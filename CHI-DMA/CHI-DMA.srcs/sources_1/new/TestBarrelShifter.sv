`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08.09.2022 11:28:43
// Design Name: 
// Module Name: TestBarrelShifter
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

`define MaxCrds           15
`define CrdRegWidth       4  // log2(MaxCrds)

module TestBarrelShifte#(
//--------------------------------------------------------------------------
  parameter CHI_DATA_WIDTH      = 64                    , // Bytes
  parameter SHIFT_WIDTH         = $clog2(CHI_DATA_WIDTH), // log2(CHI_DATA_WIDTH)  
  parameter BRAM_COL_WIDTH      = 32                    ,
  parameter BRAM_ADDR_WIDTH     = 10                    ,
  parameter DATA_FIFO_LENGTH    = 32                    ,
  parameter CMD_FIFO_LENGTH     = 32                    ,
  parameter Chunk               = 5                     ,
  parameter NUM_OF_REPETITIONS  = 100000
//--------------------------------------------------------------------------
);
     reg                                                 RST           ;
     reg                                                 Clk           ;
     CHI_Command                                         CommandIn     ;
     reg                                                 EnqueueIn     ;
     reg                                                 ValidDataBS   ;
     DatInbChannel                                       DatInbChan()  ;// Data inbound Chanel
     wire                     [CHI_DATA_WIDTH   - 1 : 0] BEOut         ;
     wire                     [CHI_DATA_WIDTH*8 - 1 : 0] DataOut       ;
     wire                     [`RspErrWidth     - 1 : 0] DataError     ;
     wire                     [BRAM_ADDR_WIDTH  - 1 : 0] DescAddr      ;
     wire                                                LastDescTrans ;
     wire                                                ReadyDataBS   ;
     wire                                                FULLCmndBS    ;
     
    localparam period           = 20   ;   // duration for each bit = 20 * timescale = 20 * 1 ns  = 20ns  
    
    BarrelShifter#(
     .  CHI_DATA_WIDTH  (CHI_DATA_WIDTH             ),
     .  BRAM_COL_WIDTH  (BRAM_COL_WIDTH             ),
     .  BRAM_ADDR_WIDTH (BRAM_ADDR_WIDTH            ),
     .  CMD_FIFO_LENGTH (CMD_FIFO_LENGTH            ),
     .  DATA_FIFO_LENGTH(DATA_FIFO_LENGTH           )
    
     )UUT(
     .  RST             (  RST                      ),
     .  Clk             (  Clk                      ),
     .  CommandIn       (  CommandIn                ),
     .  EnqueueIn       (  EnqueueIn                ),
     .  ValidDataBS     (  ValidDataBS              ),
     .  DatInbChan      (  DatInbChan     . INBOUND ),
     .  BEOut           (  BEOut                    ),
     .  DataOut         (  DataOut                  ),
     .  DataError       (  DataError                ),
     .  DescAddr        (  DescAddr                 ),
     .  LastDescTrans   (  LastDescTrans            ),
     .  ReadyDataBS     (  ReadyDataBS              ),
     .  FULLCmndBS      (  FULLCmndBS               )
    );                
    //count Credits
    reg [`CrdRegWidth - 1 : 0]CntCrds ;
    
    //generate a random vector of CHI_DATA_WIDTH bits
    reg [CHI_DATA_WIDTH*8 - 1 : 0]randVect;
    genvar i ;
    generate 
    for(i = 0 ; i < CHI_DATA_WIDTH ; i++)
      always 
          begin
          #period;
            randVect[(i+1)*8 - 1:i*8] = $urandom();
          #period; // high for 20 * timescale = 20 ns
      end 
    endgenerate;
    
    // CLk
    always 
    begin
        Clk = 1'b1; 
        #20; // high for 20 * timescale = 20 ns
    
        Clk = 1'b0;
        #20; // low for 20 * timescale = 20 ns
    end 
    
    // manage Count Crds Counter
    always_ff@(posedge Clk)begin
      if(RST)
        CntCrds = 0 ;
      else  
        if(DatInbChan.RXDATLCRDV & !DatInbChan.RXDATFLITV)
          CntCrds = CntCrds + 1 ;
        else if(!DatInbChan.RXDATLCRDV & DatInbChan.RXDATFLITV)
          CntCrds = CntCrds - 1 ;
    end
    
    // Manage Data In
    always begin
      if(RST)begin
        DatInbChan.RXDATFLITV = 0 ;
        DatInbChan.RXDATFLIT  = 0 ;
        #(period);
      end
      else begin
        DatInbChan.RXDATFLITV = 0 ;
        DatInbChan.RXDATFLIT  = 0 ;
        #(period*2*$urandom_range(0,3) + period); // wait for random delay for the next CHI-Data in
        if(CntCrds != 0 & !(UUT.EmptyCom))begin
          DatInbChan.RXDATFLITV      = 1        ;
          DatInbChan.RXDATFLIT.Data  = randVect ;
          #(period*2);
        end 
        DatInbChan.RXDATFLITV      = 0 ;
        DatInbChan.RXDATFLIT.Data  = 0 ;
        #period;
      end
    end
    
    // always ask for Data from BS
    assign ValidDataBS = 1 ;
    
    // manage inputs
    initial
        begin       
        RST                               <= 1 ;
        CommandIn.SrcAddr                 <= 0 ;
        CommandIn.DstAddr                 <= 0 ;
        CommandIn.Length                  <= 0 ;
        EnqueueIn                         <= 0 ;
        DatInbChan.RXDATFLITV             <= 0 ;
        DatInbChan.RXDATFLIT.Data         <= 0 ;
        
        #(period*2); // wait for period
        # period   ; // wait for period     
                                            
       //case 1 (all Read and Write Bytes are in one line )
          RST                    <= 0       ;
          CommandIn.SrcAddr      <= 5       ;
          CommandIn.DstAddr      <= 64 + 10 ;
          CommandIn.Length       <= 10      ;
          EnqueueIn              <= 1       ;
        
        #(period*2); // wait for period
        //case 2 (aligned Addr)
          RST                    <= 0       ;
          CommandIn.SrcAddr      <= 5       ;
          CommandIn.DstAddr      <= 64 + 5  ;
          CommandIn.Length       <= 128     ;
          EnqueueIn              <= 1       ;
        
        #(period*2); // wait for period
        //case 3 (Shift left NumbOfRead == NumOfWrite )
          RST                    <= 0       ;
          CommandIn.SrcAddr      <= 5       ;
          CommandIn.DstAddr      <= 64 + 10 ;
          CommandIn.Length       <= 128     ;
          EnqueueIn              <= 1       ;
       
        #(period*2); // wait for period  
        //case 4 (Shift left NumbOfRead != NumOfWrite )
          RST                    <= 0       ;
          CommandIn.SrcAddr      <= 5       ;
          CommandIn.DstAddr      <= 64 + 10 ;
          CommandIn.Length       <= 122     ;
          EnqueueIn              <= 1       ;
       
        #(period*2); // wait for period 
        //case 5 (Shift right NumbOfRead == NumOfWrite )
          RST                    <= 0       ;
          CommandIn.SrcAddr      <= 10      ;
          CommandIn.DstAddr      <= 64 + 5  ;
          CommandIn.Length       <= 128     ;
          EnqueueIn              <= 1       ;
       
        #(period*2); // wait for period 
        //case 6 (Shift right NumbOfRead != NumOfWrite )
          RST                    <= 0       ;
          CommandIn.SrcAddr      <= 10      ;
          CommandIn.DstAddr      <= 64 + 5  ;
          CommandIn.Length       <= 122     ;
          EnqueueIn              <= 1       ;
        
        #(period*2); // wait for period 
        //case 7 (one Read 2 Writes )
          RST                    <= 0       ;
          CommandIn.SrcAddr      <= 5       ;
          CommandIn.DstAddr      <= 64 + 10 ;
          CommandIn.Length       <= 59      ;
          EnqueueIn              <= 1       ;
        
        #(period*2); // wait for period 
          RST                    <= 0 ;
          CommandIn.SrcAddr      <= 0 ;
          CommandIn.DstAddr      <= 0 ;
          CommandIn.Length       <= 0 ;
          EnqueueIn              <= 0 ;
        #(period*150); // wait until all cases are finished
        
        for( int j=7 ; j < NUM_OF_REPETITIONS ; j=j+0)begin       
          if(!FULLCmndBS & CntCrds!=0) begin
          RST                    <= 0                                                            ;
          CommandIn.SrcAddr      <= 'd64*$urandom_range(0,10**6) + $urandom_range(0,64)          ;
          CommandIn.DstAddr      <= 'd64*$urandom_range(10**6,2**32 - 1) + $urandom_range(0,64)  ;
          CommandIn.Length       <= $urandom_range(0,Chunk*CHI_DATA_WIDTH)                       ;
          EnqueueIn              <= 1                                                            ;
          j++;
          end
          #(period*2); // wait for random delay for the next enqueue
          
          RST                   <= 0 ;
          CommandIn.SrcAddr     <= 0 ;
          CommandIn.DstAddr     <= 0 ;
          CommandIn.Length      <= 0 ;
          EnqueueIn             <= 0 ;
          
          #(period*2*$urandom_range(0,3)); // wait for random delay for the next enqueue
        end
        
        #(period*2000); // wait for period
        
        end
        
      //@@@@@@@@@@@@@@@@@@@@@@@@@Check functionality@@@@@@@@@@@@@@@@@@@@@@@@@
      //generate an BE signal with each bit * 8
      wire [CHI_DATA_WIDTH*8 - 1 : 0] sigBE ;
      genvar j;
      generate
      for( j=0 ; j<CHI_DATA_WIDTH ; j++) begin 
        assign sigBE[8*j+:8] = {BEOut[j],BEOut[j],BEOut[j],BEOut[j],BEOut[j],BEOut[j],BEOut[j],BEOut[j]};
      end
      endgenerate
      
      // Vector that keeps information for ckecking the operation of Barrel Shifter
      // chunk+2 used to be sure that all data will fit in testvector as the misaligned transactions will be read more data than Chunk*CHI_DATA_WIDTH*8 
      reg [CHI_DATA_WIDTH*8*(Chunk+2) - 1 : 0]TestVector[5 - 1 : 0]; // first dimention 0 : Length , 1 : SrcAddr, 2 : DstAddr, 3 : ReadData, 4 : WriteData
      
      int DataPointerR   = 0 ; // used to place new read Data to the  right position
      int DataPointerW   = 0 ; // used to place new write Data to the right position
      int repetCount     = 0 ; // count the number of repetition
      //assign value to testvector when a command or data are dequeued from FIFOs
      always@(posedge Clk) begin
        if(RST)begin
          TestVector     <= '{default:0};
          DataPointerR   <= 0           ;
          DataPointerW   <= 0           ;
          repetCount     <= 0           ;
        end
        else begin
          if(UUT.DeqFIFO) begin
            // When Enqueue comand in BS add SrcAddr,DstAddr,Length in TestVector
            TestVector[0] <= {{(CHI_DATA_WIDTH*8*(Chunk+2) - BRAM_COL_WIDTH){1'b0}},UUT.Command.Length } ;
            TestVector[1] <= {{(CHI_DATA_WIDTH*8*(Chunk+2) - BRAM_COL_WIDTH){1'b0}},UUT.Command.SrcAddr} ; 
            TestVector[2] <= {{(CHI_DATA_WIDTH*8*(Chunk+2) - BRAM_COL_WIDTH){1'b0}},UUT.Command.DstAddr} ;
          end
          
          if(ValidDataBS & ReadyDataBS) begin
          // add extra write Data in TestVector 
                TestVector[4] <= TestVector[4] | ((DataOut & sigBE) << (DataPointerW*CHI_DATA_WIDTH*8)) ;//DataOut[i*8 +:8] == DataOut[(i+1)*8 - 1 :8*i]
            if(!UUT.DeqFIFO)
              DataPointerW <= DataPointerW + 1 ;   
            else begin
              DataPointerW <= 0                ;
            end         
          end
          
          if(UUT.DeqData)begin
          // add extra read Data in TestVector 
            TestVector[3]<= TestVector[3] | (UUT.DataFIFO.Data << DataPointerR*CHI_DATA_WIDTH*8) ;
            if(!UUT.DeqFIFO)
              DataPointerR <= DataPointerR + 1 ;  
            else begin
              DataPointerR <= 0                ;           
              repetCount   <= repetCount + 1   ;
            end      
          end
        end
      end
      
      //task that checks if results are correct
      int errorFlag ;
      always@(posedge Clk) begin
        if(UUT.DeqFIFO & !RST)begin
          #period;
          errorFlag = 0 ;
          for(int j = 0 ; j < 8*TestVector[0] ; j ++)begin
          // Ckeck if Read data have been re-positioned with the right way to create WriteData ( TestVector[2][SHIFT_WIDTH - 1 : 0] = SrcAddr % 64)
            if(TestVector[4][j + ((TestVector[2][SHIFT_WIDTH - 1 : 0])*8)] != TestVector[3][j + ((TestVector[1][SHIFT_WIDTH - 1 : 0])*8)]) 
            // if there is e problem Display it
            begin
              errorFlag = 1 ;
              $display("--ERROR :: Repetition: %d , SrcAddr -> %d , DstAddr -> %d , Length -> %d :: Bit %d of Data addr does not match ",repetCount,((TestVector[1][SHIFT_WIDTH - 1 : 0])) ,TestVector[2][SHIFT_WIDTH - 1 : 0],TestVector[0][BRAM_COL_WIDTH - 1 : 0],j);
              $display("DataSrc : %h",TestVector[3]);
              $display("DataDst : %h",TestVector[4]);
              $stop;
              break;
            end
          end
          if(errorFlag == 0)begin
            $display("Correct :: Repetition: %d , SrcAddr -> %d , DstAddr -> %d , Length -> %d ",repetCount,TestVector[1][BRAM_COL_WIDTH - 1 : 0]%64 ,TestVector[2][BRAM_COL_WIDTH - 1 : 0]%64,TestVector[0][BRAM_COL_WIDTH - 1 : 0]);
            $display("DataSrc : %h",TestVector[3]);
            $display("DataDst : %h",TestVector[4]);
          end
          TestVector[3]<='{default:0};
          TestVector[4]<='{default:0};
        end
      end
endmodule
