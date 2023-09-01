`timescale 1ns / 1ps
import CHIFlitsPkg ::*;
import CHIFIFOsPkg ::*;
//////////////////////////////////////////////////////////////////////////////////
/*Barrel Shifter(BS) is the component that receives Data responses from the external
CHI system and it is responsible for shifting and merging Data in order to be
written at the correct memory address. More specifically the number of Data
that will be read from Memory is "CHI_DATA_WIDTH" bytes as the number of Data that 
will be sent for write. However, the Source and Destination Addresses of transfers
may be an internal byte from the piece of Data that the CHI system uses for
every Data transaction(64 bytes). In addition Source and Destination address
can be misaligned within this piece of Data (ie. SrcAddr modulo CHI-DATA-
WIDTH != DstAddr modulo CHI-DATA-WIDTH) which makes the use of
Barrel Shifter necessary for adjusting the read Data so they can be ready for
write transactions. BS creates the BE field that indicates the locations of bytes
which are valide to be written. When CHI-Converter asks the data with the assertion
of ValidDataBS, the BS passes the data and the appropriate fields by activating the
ReadyDataBS output. If BS cant accept more commands it asserts the FULLCmndBS output */
//////////////////////////////////////////////////////////////////////////////////
`define MaxCrds           15
`define CrdRegWidth       4  // log2(MaxCrds)
`define RspErrWidth       2


module BarrelShifter#(
//--------------------------------------------------------------------------
  parameter CHI_DATA_WIDTH      = 64                             , // Bytes
  parameter BRAM_COL_WIDTH      = 32                             ,
  parameter BRAM_ADDR_WIDTH     = 10                             ,
  parameter CMD_FIFO_LENGTH     = 32                             ,
  parameter DATA_FIFO_LENGTH    = 32                             ,
  parameter SHIFT_WIDTH         = $clog2(CHI_DATA_WIDTH)           // log2(CHI_DATA_WIDTH)
//--------------------------------------------------------------------------
) ( 
    input                                                        RST           ,
    input                                                        Clk           ,
    input                  CHI_Command                           CommandIn     , // CHI-Command (SrcAddr,DstAddr,Length,DescAddr,LastDescTrans)
    input                                                        EnqueueIn     ,
    input                                                        ValidDataBS   ,
    DatInbChannel.INBOUND                                        DatInbChan    , // Data inbound Chanel
    output                 reg        [CHI_DATA_WIDTH   - 1 : 0] BEOut         ,
    output                 reg        [CHI_DATA_WIDTH*8 - 1 : 0] DataOut       ,
    output                            [`RspErrWidth     - 1 : 0] DataError     ,
    output                            [BRAM_ADDR_WIDTH  - 1 : 0] DescAddr      ,
    output                                                       LastDescTrans ,
    output                 reg                                   ReadyDataBS   ,
    output                                                       FULLCmndBS
    );
    
   // Transactions counters
   reg                   [BRAM_COL_WIDTH          - 1 : 0]  CountWriteBytes ;     
   reg                                                      CntReadWE       ;  
   wire                  [BRAM_COL_WIDTH          - 1 : 0]  NextReadCnt     ;   
   reg                   [BRAM_COL_WIDTH          - 1 : 0]  CountReadBytes  ;    
   reg                                                      CntWriteWE      ;  
   wire                  [BRAM_COL_WIDTH          - 1 : 0]  NextWriteCnt    ; 
   wire                  [BRAM_COL_WIDTH          - 1 : 0]  NextSrcAddr     ;  
   wire                  [BRAM_COL_WIDTH          - 1 : 0]  NextDstAddr     ; 
   // Crds register
   reg                   [`MaxCrds                - 1 : 0]  DataCrdInbound  ; // Credits for inbound Data Chanel
   reg                   [$clog2(DATA_FIFO_LENGTH)    : 0]  GivenDataCrd    ; // counter used in order not to take more DataRsp than FIFO length
   // BS merge register and signals
   reg                   [CHI_DATA_WIDTH*8        - 1 : 0] PrevShiftedData  ; // Register that stores the shifted data that came to the previous DataRsp 
   reg                                                     PrvShftdDataWE   ; // WE of register
   wire                  [CHI_DATA_WIDTH*8        - 1 : 0] ShiftedData      ; // Out of Barrel Shifted comb 
  //shif
   wire                  [SHIFT_WIDTH             - 1 : 0] shift            ; // shift amount of Barrel Shifter
  // signals of command FIFO
   wire                                                    EmptyCom         ; 
   reg                                                     DeqFIFO          ;
   reg                                                     DeqData          ;
   CHI_Command                                             Command          ;
  // signals of Data FIF
   CHI_FIFO_Data_Packet                                    DataFIFO         ;
   wire                                                    DataEmpty        ;
   CHI_FIFO_Data_Packet                                    DataFIFOIn       ;
   wire                                                    EmptyFIFO        ; // Or of every FIFO Empty
           
    
   assign LastDescTrans = DeqFIFO & Command.LastDescTrans ;
   assign DescAddr      = Command.DescAddr                ;
   assign DataError     = DataFIFO.RespErr                ;
   
   assign DataFIFOIn    = '{default : 0 , Data : DatInbChan.RXDATFLIT.Data  , RespErr : DatInbChan.RXDATFLIT.RespErr};
   // Command FIFO(SrcAddr,DstAddr,BTS,SB,DescAddr,LastDescTrans)
   FIFO #(  
       .FIFO_WIDTH   (3*BRAM_COL_WIDTH + BRAM_ADDR_WIDTH + 1 )     ,  //FIFO_WIDTH       
       .FIFO_LENGTH  (CMD_FIFO_LENGTH                        )        //FIFO_LENGTH   
       )     
       FIFOCmnd    (     
       .RST        ( RST        ) ,      
       .Clk        ( Clk        ) ,      
       .Inp        ( CommandIn  ) , 
       .Enqueue    ( EnqueueIn  ) , 
       .Dequeue    ( DeqFIFO    ) , 
       .Outp       ( Command    ) , 
       .FULL       ( FULLCmndBS ) , 
       .Empty      ( EmptyCom   ) 
       );   
          
   // Data FIFO
   FIFO #(  
       .FIFO_WIDTH   (CHI_DATA_WIDTH*8 + `RspErrWidth) ,  //FIFO_WIDTH       
       .FIFO_LENGTH  (DATA_FIFO_LENGTH               )    //FIFO_LENGTH   
       )     
       FIFOData        (             
       .RST            ( RST                                         ),     
       .Clk            ( Clk                                         ),     
       .Inp            ( DataFIFOIn                                  ),
       .Enqueue        ( DatInbChan.RXDATFLITV & DataCrdInbound != 0 ),
       .Dequeue        ( DeqData                                     ),
       .Outp           ( DataFIFO                                    ),
       .FULL           (                                             ),
       .Empty          ( DataEmpty                                   )
       );                           
    
    //----------- Manage Read-Write Req Bytes counters -----------
    assign NextSrcAddr  = Command.SrcAddr + CountReadBytes  ;
    assign NextDstAddr  = Command.DstAddr + CountWriteBytes ;
    assign NextReadCnt  = (CountReadBytes  == 0) ? ((Command.Length < (CHI_DATA_WIDTH - Command.SrcAddr[SHIFT_WIDTH - 1 : 0])) ? (Command.Length) : (CHI_DATA_WIDTH - Command.SrcAddr[SHIFT_WIDTH - 1 : 0])) : ((CountReadBytes + CHI_DATA_WIDTH < Command.Length) ? (CountReadBytes + CHI_DATA_WIDTH) : (Command.Length)) ;
    assign NextWriteCnt = (CountWriteBytes == 0) ? ((Command.Length < (CHI_DATA_WIDTH - Command.DstAddr[SHIFT_WIDTH - 1 : 0])) ? (Command.Length) : (CHI_DATA_WIDTH - Command.DstAddr[SHIFT_WIDTH - 1 : 0])) : ((CountWriteBytes + CHI_DATA_WIDTH < Command.Length) ? (CountWriteBytes + CHI_DATA_WIDTH) : (Command.Length)) ;
    always_ff@(posedge Clk)begin
      if(RST)begin
        CountWriteBytes <= 0 ;
        CountReadBytes  <= 0 ;
      end
      else begin
        if(DeqFIFO == 1)begin
          CountReadBytes <= 0         ;
        end
        else if(CntReadWE == 1)begin
        CountReadBytes <= NextReadCnt ;
        end      
          
        if( DeqFIFO == 1)begin
          CountWriteBytes <= 0            ;
        end
        else if(CntWriteWE == 1)begin
          CountWriteBytes <= NextWriteCnt ;
        end
      end      
    end
    //------------------------------------------------------------------
    
    //////////////////////Enable the corect Bytes to be written////////////////////// 
    always_comb begin
      if(NextWriteCnt == Command.Length)begin // if last trans
        if((CHI_DATA_WIDTH - Command.DstAddr[SHIFT_WIDTH - 1 : 0] >= Command.Length))begin // if address range of Data that should be written is internal of CHI_DATA_WIDTH
          BEOut = ({CHI_DATA_WIDTH{1'b1}} << Command.DstAddr[SHIFT_WIDTH - 1 : 0]) & ~({CHI_DATA_WIDTH{1'b1}} << (Command.DstAddr[SHIFT_WIDTH - 1 : 0] + Command.Length)); 
        end
        else begin
          BEOut = ~({CHI_DATA_WIDTH{1'b1}} << Command.Length - CountWriteBytes) ;  // Enable the least significant bits 
        end
      end
      else begin  // enable the most significant or all bits
        if(CountWriteBytes == 0) 
          BEOut = ({CHI_DATA_WIDTH{1'b1}} << Command.DstAddr[SHIFT_WIDTH - 1 : 0]) ;  
        else
          BEOut = {CHI_DATA_WIDTH{1'b1}} ;
      end
    end
    ////////////////////////////////////////////////////////////////////////////////////////
    
    // or of FIFOs' empty
    assign EmptyFIFO = EmptyCom | DataEmpty ;
    
    //>>>>>> Create Shift for BS comb <<<<<<<<<<
    assign shift = (Command.SrcAddr[SHIFT_WIDTH - 1 : 0] - Command.DstAddr[SHIFT_WIDTH - 1 : 0]) ;
    //>>>>>>>>>>>>>>>>>>><<<<<<<<<<<<<<<<<<<<<<<
    
    // ---------------------Barrel Shifter comb---------------------
    /*Barrel Shifter comb does a circular right shifts of its Data input by
     the amount of its shift input*/
    wire  [CHI_DATA_WIDTH*8 - 1 : 0] muxout [SHIFT_WIDTH - 1 : 0];  // muxes of Barrel Shifter
    assign muxout[0] = shift[0] ? ({DataFIFO.Data[7 : 0],DataFIFO.Data[CHI_DATA_WIDTH*8  - 1 :8]}): DataFIFO.Data ;
    genvar i ;
    generate 
    for(i = 1 ; i < SHIFT_WIDTH ; i++)
      assign muxout[i] = shift[i] ? ({muxout[i-1][2**(i + 3) - 1 : 0],muxout[i-1][CHI_DATA_WIDTH*8  - 1 : 2**(i + 3)]}): muxout[i-1] ;
    endgenerate
    assign ShiftedData = muxout[SHIFT_WIDTH - 1];
    // ---------------------end Barrel Shifter comb---------------------

    // Manage Register that stores the shifted data from BScomb
    always_ff@(posedge Clk) begin
      if(RST)
        PrevShiftedData <= 0 ;
      else
        if(PrvShftdDataWE)begin
          PrevShiftedData <= ShiftedData ;
        end
    end    
    
    //-------------------------------------Crds manager------------------------------------
     always_ff @ (posedge Clk) begin
     if(RST)begin
       DataCrdInbound <= 0 ;        // Reset FSM
       GivenDataCrd   <= 0 ;
     end        
     else begin
       // Inbound Data chanle Crd Counter
       if(DatInbChan.RXDATLCRDV & !(DataCrdInbound != 0 & DatInbChan.RXDATFLITV))
         DataCrdInbound <= DataCrdInbound + 1 ;
       else if(!DatInbChan.RXDATLCRDV & (DataCrdInbound != 0 & DatInbChan.RXDATFLITV))
         DataCrdInbound <= DataCrdInbound - 1 ;
       // Count the number of given Data Crds in order not to give more than DATA FIFO length
       if(DatInbChan.RXDATLCRDV & !DeqData)
         GivenDataCrd <= GivenDataCrd + 1 ;       
       else if(!DatInbChan.RXDATLCRDV & DeqData)
         GivenDataCrd <= GivenDataCrd - 1 ;
     end
   end
   // Give an extra Crd in outbound Data Chanel
   assign DatInbChan.RXDATLCRDV = !RST & (GivenDataCrd < CMD_FIFO_LENGTH & DataCrdInbound < `MaxCrds) ;
  //------------------------------------End Crds manager------------------------------------ 
  
  //################################ Control  ################################
  always_comb begin
    begin                      
      if(EmptyFIFO)begin     // if one of FIFOs is empty then BS is empty and do nothing
        ReadyDataBS    = 0 ;
        CntReadWE      = 0 ;
        CntWriteWE     = 0 ;
        DataOut        = 0 ;
        PrvShftdDataWE = 0 ;
        DeqFIFO        = 0 ;
        DeqData        = 0 ;
      end
      // if last read-write of aligned Transaction or all bytes of read and write are within one line respectively give only shifted Data , update counters,and dequeue Data FIFO and Cmnd FIFOs
      else if(ValidDataBS & (NextWriteCnt == Command.Length) & (NextReadCnt == Command.Length) & (shift == 0 | (((CountReadBytes == 0) & (CountWriteBytes == 0)))))begin
        ReadyDataBS    = 1           ;
        CntReadWE      = 1           ;
        CntWriteWE     = 1           ;
        PrvShftdDataWE = 1           ;
        DeqFIFO        = 1           ;
        DeqData        = 1           ;  
        DataOut        = ShiftedData ;
      end
      // if non last aligned Transaction give shifted Data , update counters,and dequeue Data FIFO
      else if(ValidDataBS & (shift == 0))begin
        ReadyDataBS    = 1           ;
        CntReadWE      = 1           ;
        CntWriteWE     = 1           ;
        PrvShftdDataWE = 1           ;
        DeqFIFO        = 0           ;
        DeqData        = 1           ;  
        DataOut        = ShiftedData ;
      end
      // when last Read and Writethen (but all bytes of read and write are not within one line)give merged Data for Write , update counters,and dequeue Data FIFO and Cmnd FIFOs
      else if(ValidDataBS & (((NextReadCnt == Command.Length) & (NextWriteCnt == Command.Length))))begin
        ReadyDataBS    = 1                                                                                                                                                ;
        CntReadWE      = 1                                                                                                                                                ;
        CntWriteWE     = 1                                                                                                                                                ;
        PrvShftdDataWE = 1                                                                                                                                                ;
        DeqFIFO        = 1                                                                                                                                                ;
        DeqData        = 1                                                                                                                                                ;  
        DataOut        = (ShiftedData & (~({(CHI_DATA_WIDTH*8){1'b1}} >> ({shift,{3{1'b0}}})))) | (PrevShiftedData & ({(CHI_DATA_WIDTH*8){1'b1}} >> ({shift,{3{1'b0}}}))) ; // = {ShiftedData[CHI_DATA_WIDTH-1:CHI_DATA_WIDTH-shift],PrevShiftedData[CHI_DATA_WIDTH-shift-1:0]}, shift = shift*8 (for shifting bits)
      end
      // When Data must be shifted right and its the first Read then no enough data for a write dont give Data, Dequeue Data FIFO and update Read Counter 
      else if((Command.DstAddr[SHIFT_WIDTH - 1 : 0] < Command.SrcAddr[SHIFT_WIDTH - 1 : 0]) & CountReadBytes == 0 & NextReadCnt < Command.Length)begin  
        ReadyDataBS    = 0 ; // Barrel Shifter is empty because there are not enough data for a Write
        CntReadWE      = 1 ; // Update Read Counter
        CntWriteWE     = 0 ; // Dont update Write Counter because there are not enough data for a Write
        DataOut        = 0 ; // Output Data
        PrvShftdDataWE = 1 ; // Write shifted Data in register 
        DeqFIFO        = 0 ; // Dont Dequeue FIFOs (SrcAddr,DstAddr,Legnth)
        DeqData        = 1 ; // Dequeue Data FIFO because there are Data that have been read
      end
      // when not last Read and Write (but not first Read with right shift) then give merged Data for Write, update counters,and dequeue Data FIFO and Cmnd FIFOs
      else if(ValidDataBS & (((NextReadCnt < Command.Length) & (NextWriteCnt < Command.Length))))begin
        ReadyDataBS    = 1                                                                                                                                                ;
        CntReadWE      = 1                                                                                                                                                ;
        CntWriteWE     = 1                                                                                                                                                ;
        PrvShftdDataWE = 1                                                                                                                                                ;
        DeqFIFO        = 0                                                                                                                                                ;
        DeqData        = 1                                                                                                                                                ; 
        DataOut        = (ShiftedData & (~({(CHI_DATA_WIDTH*8){1'b1}} >> ({shift,{3{1'b0}}})))) | (PrevShiftedData & ({(CHI_DATA_WIDTH*8){1'b1}} >> ({shift,{3{1'b0}}}))) ; // = {ShiftedData[CHI_DATA_WIDTH-1:CHI_DATA_WIDTH-shift],PrevShiftedData[CHI_DATA_WIDTH-shift-1:0]}, shift = shift*8 (for shifting bits)
      end
      // When last Read but not last Write so data must be shifted left then give merged data for write (read must become 2 writes), update Write Coubter
      else if(ValidDataBS & (NextReadCnt == Command.Length) & (NextWriteCnt < Command.Length))begin 
        ReadyDataBS    = 1                                                                                                                                                ;
        CntReadWE      = 0                                                                                                                                                ; // Dont Update Read Counter because it is the last Read but not last write
        CntWriteWE     = 1                                                                                                                                                ; // Update Write Counter
        PrvShftdDataWE = 1                                                                                                                                                ; 
        DeqFIFO        = 0                                                                                                                                                ;
        DeqData        = 0                                                                                                                                                ;
        DataOut        = (ShiftedData & (~({(CHI_DATA_WIDTH*8){1'b1}} >> ({shift,{3{1'b0}}})))) | (PrevShiftedData & ({(CHI_DATA_WIDTH*8){1'b1}} >> ({shift,{3{1'b0}}}))) ; // = {ShiftedData[CHI_DATA_WIDTH-1:CHI_DATA_WIDTH-shift],PrevShiftedData[CHI_DATA_WIDTH-shift-1:0]}, shift = shift*8 (for shifting bits)
      end
      // if ValidDataBS == 0 and not shift right
      else begin  
        ReadyDataBS    = 0 ;
        CntReadWE      = 0 ;
        CntWriteWE     = 0 ;
        DataOut        = 0 ; 
        PrvShftdDataWE = 0 ;
        DeqFIFO        = 0 ;
        DeqData        = 0 ;
      end              
    end
  end
   //################################ END Control  ################################
endmodule
