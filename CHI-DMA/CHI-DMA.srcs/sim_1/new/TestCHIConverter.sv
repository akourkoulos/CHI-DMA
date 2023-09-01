`timescale 1ns / 1ps
import DataPkg::*;
import CHIFlitsPkg::*; 
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07.10.2022 16:52:48
// Design Name: 
// Module Name: TestCHIConverter
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

// Req opcode
`define ReadOnce          6'h03 
`define WriteUniquePtl    6'h18
//Data opcoed
`define CompData          4'h4
// Rsp opcode
`define DBIDResp          4'h3
`define CompDBIDResp      4'h5
//Data opcode
`define NonCopyBackWrData 4'h3
`define NCBWrDataCompAck  4'hc
`define CompData          4'h4

`define MaxCrds           15

`define DBIDRespWidth     8
`define TxnIDWidth        8
`define RspErrWidth       2

`define StatusError       2
 
module TestCHIConverter#(
//--------------------------------------------------------------------------
  parameter BRAM_ADDR_WIDTH    = 10  ,
  parameter BRAM_NUM_COL       = 8   , // As the Data_packet fields
  parameter BRAM_COL_WIDTH     = 32  ,
  parameter CMD_FIFO_LENGTH    = 32  ,
  parameter DBID_FIFO_LENGTH   = 32  ,
  parameter MEM_ADDR_WIDTH     = 44  ,
  parameter CHI_DATA_WIDTH     = 64  , //Bytes
  parameter QoS                 = 8  , 
  parameter TgtID               = 2  , 
  parameter SrcID               = 1  ,  
//--------Simulation parameters--------  
  parameter Chunk              = 5   ,
  parameter NUM_OF_REPETITIONS = 250 ,
  parameter FIFO_Length        = 128
//----------------------------------------------------------------------
  );
   reg                                              Clk               ;                                                                                        
   reg                                              RST               ;                                                                                        
   Data_packet                                      DataBRAM          ; // From BRAM 
   reg                                              ReadyBRAM         ; // From Arbiter_BRAM                                                                   
   reg                                              IssueValid        ; // From Scheduler                                                                                       
   CHI_Command                                      Command           ; // CHI-Command (SrcAddr,DstAddr,Length,DescAddr,LastDescTrans)                                                                                                                
   ReqChannel                                       ReqChan      ()   ; // Request ChannelS                                                                    
   RspOutbChannel                                   RspOutbChan  ()   ; // Response outbound Chanel                                                            
   DatOutbChannel                                   DatOutbChan  ()   ; // Data outbound Chanel                                                                
   RspInbChannel                                    RspInbChan   ()   ; // Response inbound Chane
   DatInbChannel                                    DatInbChan   ()   ;
   wire                                             CmdFIFOFULL       ; // For Scheduler                                                                       
   wire                                             ValidBRAM         ; // For Arbiter_BRAM                                                                    
   wire                   [BRAM_ADDR_WIDTH - 1 : 0] AddrBRAM          ; // For BRAM                                                                            
   Data_packet                                      DescStatus        ;                                                                                        
   wire                   [BRAM_NUM_COL    - 1 : 0] WEBRAM            ;                                                                                           
                      
    // duration for each bit = 20 * timescdoutBale = 20 * 1 ns  = 20ns
    localparam period = 20;  
    // signals BS                                                                                                                                       
    CHI_Command                            CommandIn     ;
    wire                                   EnqueueIn     ;
    wire                                   ValidDataBS   ;
    wire        [CHI_DATA_WIDTH   - 1 : 0] BEOut         ;
    wire        [CHI_DATA_WIDTH*8 - 1 : 0] DataOut       ;
    wire                                   ReadyDataBS   ;
    wire                                   FULLCmndBS    ;
    wire        [`RspErrWidth     - 1 : 0] DataError     ;
    wire                                   LastDescTrans ;
    wire        [BRAM_ADDR_WIDTH  - 1 : 0] DescAddr      ;

    CHIConverter #(    
//--------------------------------------------------------------------------
//-----------------------------BRAM-Parameters------------------------------  
   .BRAM_ADDR_WIDTH   (BRAM_ADDR_WIDTH   )            ,
   .BRAM_NUM_COL      (BRAM_NUM_COL      )            , //As the Data_packet fields
   .BRAM_COL_WIDTH    (BRAM_COL_WIDTH    )            ,
   .CMD_FIFO_LENGTH   (CMD_FIFO_LENGTH   )            ,
   .DBID_FIFO_LENGTH  (DBID_FIFO_LENGTH  )            ,
   .MEM_ADDR_WIDTH    (MEM_ADDR_WIDTH    )            , 
   .CHI_DATA_WIDTH    (CHI_DATA_WIDTH    )            , //Bytes
   .QoS               (QoS               )            , 
   .TgtID             (TgtID             )            , 
   .SrcID             (SrcID             )              

)UUT(
     .Clk                (Clk                      ) ,
     .RST                (RST                      ) ,
     .DataBRAM           (DataBRAM                 ) ,
     .IssueValid         (IssueValid               ) ,
     .ReadyBRAM          (ReadyBRAM                ) ,
     .Command            (Command                  ) ,                                       
     .LastDescTrans      (LastDescTrans            ) ,                                       
     .DescAddr           (DescAddr                 ) ,                                       
     .BE                 (BEOut                    ) ,                                       
     .ShiftedData        (DataOut                  ) ,                                       
     .DataErr            (DataError                ) ,
     .ReadyDataBS        (ReadyDataBS              ) ,
     .FULLCmndBS         (FULLCmndBS               ) ,
     .ReqChan            (ReqChan      .OUTBOUND   ) ,
     .RspOutbChan        (RspOutbChan  .OUTBOUND   ) ,
     .DatOutbChan        (DatOutbChan  .OUTBOUND   ) ,   
     .RspInbChan         (RspInbChan   .INBOUND    ) ,
     .RXDATFLITV         (DatInbChan   .RXDATFLITV ) ,
     .CmdFIFOFULL        (CmdFIFOFULL              ) ,
     .ValidBRAM          (ValidBRAM                ) ,
     .AddrBRAM           (AddrBRAM                 ) ,
     .DescStatus         (DescStatus               ) ,
     .WEBRAM             (WEBRAM                   ) ,
     .EnqueueBS          (EnqueueIn                ) ,
     .CommandBS          (CommandIn                ) ,
     .ValidDataBS        (ValidDataBS              )
    );
    
     BarrelShifter BS (
     .  RST              ( RST                       ),
     .  Clk              ( Clk                       ),
     .  CommandIn        ( CommandIn                 ),
     .  EnqueueIn        ( EnqueueIn                 ),
     .  ValidDataBS      ( ValidDataBS               ),
     .  DatInbChan       ( DatInbChan      . INBOUND ),
     .  BEOut            ( BEOut                     ),
     .  DataOut          ( DataOut                   ),
     .  DataError        ( DataError                 ),
     .  DescAddr         ( DescAddr                  ),
     .  LastDescTrans    ( LastDescTrans             ),
     .  ReadyDataBS      ( ReadyDataBS               ),
     .  FULLCmndBS       ( FULLCmndBS                )
    );      
    
    //Crds signals
    int                               CountDataCrdsInb  = 0  ; 
    int                               CountRspCrdsInb   = 0  ;
    int                               CountReqCrdsOutb  = 0  ; 
    int                               CountDataCrdsOutb = 0  ;
    int                               CountRspCrdsOutb  = 0  ;
    reg     [31 : 0]                  GivenReqCrds           ;// use in order not to give more crds than fifo length
    //FIFO signals
    reg                               SigDeqReqR             ;
    reg                               SigReqEmptyR           ;
    reg                               SigDeqReqW             ;
    reg                               SigReqEmptyW           ;
    ReqFlit                           SigTXREQFLITR          ;
    ReqFlit                           SigTXREQFLITW          ;
    //Next DBID
    int                               DBID_Count        = 0  ; 
    
    // Read Req FIFO (keeps all the uncomplete read Requests)
   FIFO #(     
       .FIFO_WIDTH  ( REQ_FLIT_WIDTH ) ,       
       .FIFO_LENGTH ( FIFO_Length    )      
       )     
       myRFIFOReq(     
       .RST      ( RST                                                                                ) ,      
       .Clk      ( Clk                                                                                ) ,      
       .Inp      ( ReqChan.TXREQFLIT                                                                  ) , 
       .Enqueue  ( ReqChan.TXREQFLITV & ReqChan.TXREQFLIT.Opcode == `ReadOnce & CountReqCrdsOutb != 0 ) , 
       .Dequeue  ( SigDeqReqR                                                                         ) , 
       .Outp     ( SigTXREQFLITR                                                                      ) , 
       .FULL     (                                                                                    ) , 
       .Empty    ( SigReqEmptyR                                                                       ) 
       );
       
    // Write Req FIFO (keeps all the uncomplete read Writeuests)
   FIFO #(     
       .FIFO_WIDTH  ( REQ_FLIT_WIDTH ) ,       
       .FIFO_LENGTH ( FIFO_Length    )      
       )     
       myWFIFOReq(     
       .RST      ( RST                                                                                     ) ,      
       .Clk      ( Clk                                                                                     ) ,      
       .Inp      ( ReqChan.TXREQFLIT                                                                       ) , 
       .Enqueue  ( ReqChan.TXREQFLITV & ReqChan.TXREQFLIT.Opcode == `WriteUniquePtl & CountReqCrdsOutb != 0) , 
       .Dequeue  ( SigDeqReqW                                                                              ) , 
       .Outp     ( SigTXREQFLITW                                                                           ) , 
       .FULL     (                                                                                         ) , 
       .Empty    ( SigReqEmptyW                                                                            ) 
       );
       
    
    always
    begin
        Clk = 1'b0; 
        #20; // high for 20 * timescale = 20 ns
    
        Clk = 1'b1;
        #20; // low for 20 * timescale = 20 ns
    end
    
    //Signals for Completer
    always_comb begin
      if(ValidBRAM) begin
         ReadyBRAM                = 1                    ;
         DataBRAM.SrcAddr         = $urandom()           ;
         DataBRAM.DstAddr         = $urandom()           ;
         DataBRAM.BytesToSend     = $urandom()           ;
         DataBRAM.SentBytes       = DataBRAM.BytesToSend ;
         DataBRAM.Status          = 1                    ;
      end
      else begin
         ReadyBRAM                = 0 ;
         DataBRAM.SrcAddr         = 0 ;
         DataBRAM.DstAddr         = 0 ;
         DataBRAM.BytesToSend     = 0 ;
         DataBRAM.SentBytes       = 0 ;
         DataBRAM.Status          = 0 ;
      end
    end
    
    //Count inbound Crds
    always_ff@(posedge Clk) begin
      if(RST)begin
        CountDataCrdsInb = 0 ;
        CountRspCrdsInb  = 0 ;
      end
      else begin
        if(DatInbChan.RXDATLCRDV & !DatInbChan.RXDATFLITV)
          CountDataCrdsInb <= CountDataCrdsInb + 1;
        else if(!DatInbChan.RXDATLCRDV & DatInbChan.RXDATFLITV)
          CountDataCrdsInb <= CountDataCrdsInb - 1;
        if(RspInbChan.RXRSPLCRDV & !RspInbChan.RXRSPFLITV) 
          CountRspCrdsInb <= CountRspCrdsInb + 1 ; 
        else if(!RspInbChan.RXRSPLCRDV & RspInbChan.RXRSPFLITV) 
          CountRspCrdsInb <= CountRspCrdsInb - 1; 
      end
    end
    
    // use in order not to give more crds than fifo length
    always_ff@(posedge Clk) begin
      if(RST)
        GivenReqCrds <= 0;
      else begin
        if(!(DatInbChan.RXDATFLITV) & !(RspInbChan.RXRSPFLITV) & ReqChan.TXREQLCRDV)
          GivenReqCrds <= GivenReqCrds + 1 ;
        else if((DatInbChan.RXDATFLITV) & !(RspInbChan.RXRSPFLITV) & (!ReqChan.TXREQLCRDV) & GivenReqCrds != 0)
          GivenReqCrds <= GivenReqCrds - 1 ;
        else if(!(DatInbChan.RXDATFLITV) & (RspInbChan.RXRSPFLITV) & (!ReqChan.TXREQLCRDV) & GivenReqCrds != 0)
          GivenReqCrds <= GivenReqCrds - 1 ;
        else if((DatInbChan.RXDATFLITV) & (RspInbChan.RXRSPFLITV) & (ReqChan.TXREQLCRDV) & GivenReqCrds != 0)
          GivenReqCrds <= GivenReqCrds - 1 ;
        else if((DatInbChan.RXDATFLITV) & (RspInbChan.RXRSPFLITV) & (!ReqChan.TXREQLCRDV) & GivenReqCrds > 1)
          GivenReqCrds <= GivenReqCrds - 2 ;
      end
    end
    
    //give Outbound Crds
    always begin
      if(RST)begin
        ReqChan.TXREQLCRDV = 0;
        #period;
      end
      else begin
        ReqChan.TXREQLCRDV = 0;
        #(2*period*$urandom_range(2));
        if(GivenReqCrds < FIFO_Length & CountReqCrdsOutb < `MaxCrds)
          ReqChan.TXREQLCRDV = 1;
        #(2*period);
      end
    end
    always begin
      if(RST) begin
        RspOutbChan.TXRSPLCRDV = 0;
        #period;
      end
      else begin
        RspOutbChan.TXRSPLCRDV = 0;
        #(2*period*$urandom_range(5));
        if(CountRspCrdsOutb < `MaxCrds)
          RspOutbChan.TXRSPLCRDV = 1;
        #(2*period);
      end
    end
    always begin
      if(RST) begin
        DatOutbChan.TXDATLCRDV = 0;
        #period;
      end
      else begin
        DatOutbChan.TXDATLCRDV = 0;
        #(2*period*$urandom_range(5));
        if(CountDataCrdsOutb < `MaxCrds)
          DatOutbChan.TXDATLCRDV = 1;
        #(2*period);
      end
    end
    
    //Count Outbound Crds
    always_ff@(posedge Clk) begin
      if(RST)begin
        CountDataCrdsOutb = 0 ;
        CountRspCrdsOutb  = 0 ;
        CountReqCrdsOutb  = 0 ;
      end
      else begin
        if(DatOutbChan.TXDATLCRDV & !DatOutbChan.TXDATFLITV)
          CountDataCrdsOutb <= CountDataCrdsOutb + 1;
        else if(!DatOutbChan.TXDATLCRDV & DatOutbChan.TXDATFLITV)
          CountDataCrdsOutb <= CountDataCrdsOutb - 1;
        if(RspOutbChan.TXRSPLCRDV & !RspOutbChan.TXRSPFLITV) 
          CountRspCrdsOutb <= CountRspCrdsOutb + 1; 
        else if(!RspOutbChan.TXRSPLCRDV & RspOutbChan.TXRSPFLITV) 
          CountRspCrdsOutb <= CountRspCrdsOutb - 1; 
        if(ReqChan.TXREQLCRDV & !ReqChan.TXREQFLITV) 
          CountReqCrdsOutb <= CountReqCrdsOutb + 1; 
        else if(!ReqChan.TXREQLCRDV & ReqChan.TXREQFLITV) 
          CountReqCrdsOutb <= CountReqCrdsOutb - 1 ; 
      end
    end
    
    // Data Response
    always begin     
      if(!SigReqEmptyR & SigTXREQFLITR.Opcode == `ReadOnce & CountDataCrdsInb != 0)begin
        
          DatInbChan.RXDATFLITPEND     = 0      ;
          DatInbChan.RXDATFLITV        = 0      ;
          DatInbChan.RXDATFLIT         = 0      ;
          SigDeqReqR                   = 0      ;
          //Response delay
          #(2*period*$urandom_range(70));  // random delay if addresses arent continuous
          DatInbChan.RXDATFLITV = 1;
          DatInbChan.RXDATFLIT = '{default     : 0                                            ,                       
                                    QoS        : 0                                            ,
                                    TgtID      : 1                                            ,
                                    SrcID      : 2                                            ,
                                    TxnID      : SigTXREQFLITR.TxnID                          ,
                                    HomeNID    : 0                                            ,
                                    Opcode     : `CompData                                    ,
                                    RespErr    : `StatusError*(($urandom_range(0,100)) == 1)  , // samll probability to be an error
                                    Resp       : 0                                            , // Resp should be 0 when NonCopyBackWrData Rsp
                                    DataSource : 0                                            , 
                                    DBID       : 0                                            ,
                                    CCID       : 0                                            , 
                                    DataID     : 0                                            ,
                                    TraceTag   : 0                                            ,
                                    BE         : {64{1'b1}}                                   ,
                                    Data       : 2**$urandom_range(0,512) - $urandom()        ,  //512 width of data
                                    DataCheck  : 0                                            ,
                                    Poison     : 0                                        
                                    }; 
          SigDeqReqR  = 1      ;
          #(period*2);
          
      end
      else begin
        DatInbChan.RXDATFLITPEND     = 0      ;
        DatInbChan.RXDATFLITV        = 0      ;
        DatInbChan.RXDATFLIT         = 0      ;
        SigDeqReqR                   = 0      ;
        #(period*2) ;
      end
    end
    
    //DBID Respose 
    always begin
      if(!SigReqEmptyW & SigTXREQFLITW.Opcode == `WriteUniquePtl & CountRspCrdsInb != 0)begin
        RspInbChan.RXRSPFLITPEND     = 0      ;
        RspInbChan.RXRSPFLITV        = 0      ;
        RspInbChan.RXRSPFLIT         = 0      ;
        SigDeqReqW                   = 0      ;
        #(2*period*$urandom_range(30)) //response delay
        RspInbChan.RXRSPFLITV = 1;
        RspInbChan.RXRSPFLIT = '{default   : 0                                        ,                       
                                  QoS      : 0                                        ,
                                  TgtID    : 1                                        ,
                                  SrcID    : 2                                        ,
                                  TxnID    : SigTXREQFLITW.TxnID                      ,
                                  Opcode   : `CompDBIDResp                            ,
                                  RespErr  : 0                                        ,
                                  Resp     : 0                                        ,
                                  FwdState : 0                                        , // Resp should be 0 when NonCopyBackWrData Rsp
                                  DBID     : DBID_Count                               , // new DBID for every Rsp
                                  PCrdType : 0                                        ,
                                  TraceTag : 0                                       
                                  };     
        DBID_Count <= DBID_Count + 1; //increase DBID pointer
        SigDeqReqW = 1;
        #(period*2);
      end
      else begin
        RspInbChan.RXRSPFLITPEND     = 0      ;
        RspInbChan.RXRSPFLITV        = 0      ;
        RspInbChan.RXRSPFLIT         = 0      ;      
        SigDeqReqW                   = 0      ;
        #(period*2) ;
      end
    end
    
    // Insert Command 
    initial
        begin
          // Reset;
         RST                       = 1      ;
         Command.SrcAddr           = 'd10   ;
         Command.DstAddr           = 'd1000 ;
         Command.Length            = 'd320  ;
         IssueValid                = 0      ;
         Command.DescAddr          = 'd1    ;
         Command.LastDescTrans     = 0      ;
         
         #(period*2); // wait for period   
         
          RST                         = 0                                      ;
          Command.SrcAddr             = 6                                      ;
          Command.DstAddr             = 65                                     ;                                                           
          IssueValid                  = 1                                      ;
          Command.DescAddr            = 1                                      ;
          Command.LastDescTrans       = 0                                      ; // If last trans LastDescTrans=1 
          Command.Length              = 2*CHI_DATA_WIDTH +5                    ; // and length < CHI_CHI_DATA_WIDTH * Chunk
          
         #(period*2); // wait for period   
         
         for(int i = 2 ; i < NUM_OF_REPETITIONS+1 ; i = i)begin
           RST                         = 0                                      ;
           Command.SrcAddr             =            $urandom_range(10000)       ;
           Command.DstAddr             = 'd100000 * $urandom_range(10000) + 1   ;
           if(CmdFIFOFULL)begin        // Issue Command when CommandFIFO is not FULL                                 
             IssueValid                = 0                                      ;
           end                                                                  
           else begin                                                           
             IssueValid                = 1                                      ;
             i++                                                                ;
           end                                                                  
           Command.DescAddr            = i                                      ;
           if($urandom_range(0,5) == 1)begin //20% chance to be the last transaction of Desc
             Command.LastDescTrans = 1                                          ; // If last trans LastDescTrans=1 
             Command.Length            = $urandom_range(1,CHI_DATA_WIDTH*Chunk) ; // and length < CHI_CHI_DATA_WIDTH * Chunk
           end
           else begin
             Command.LastDescTrans     = 0                                      ; 
             Command.Length            = $urandom_range(1,CHI_DATA_WIDTH*Chunk) ;
           end
          
           #(period*2); // wait for period  
           
           if(IssueValid == 1)begin
             RST                       = 0  ;                                   
             Command.SrcAddr           = 0  ;      
             Command.DstAddr           = 0  ;
             Command.Length            = 0  ;
             IssueValid                = 0  ;                                   
             Command.DescAddr          = 0  ;                                   
             Command.LastDescTrans     = 0  ;                                   
             
             #(period*2 + 2*period*$urandom_range(4));
           end
         end
         //stop
         RST                       = 0  ;                                   
         Command.SrcAddr           = 0  ;      
         Command.DstAddr           = 0  ;
         Command.Length            = 0  ;
         IssueValid                = 0  ;                                   
         Command.DescAddr          = 0  ;                                   
         Command.LastDescTrans     = 0  ;                                   
         
         while(1)
           #(period*2); // wait for period   
    end
    
    //@@@@@@@@@@@@@@@@@@@@@@@@@Check functionality@@@@@@@@@@@@@@@@@@@@@@@@@
      // Vector that keeps information for ckecking the operation of CHI-COnverter
      CHI_Command [NUM_OF_REPETITIONS         - 1 : 0]  TestVectorCommand     ; 
      ReqFlit     [NUM_OF_REPETITIONS*Chunk*2 - 1 : 0]  TestVectorReadReq     ; 
      ReqFlit     [NUM_OF_REPETITIONS*Chunk*2 - 1 : 0]  TestVectorWriteReq    ; 
      DataFlit    [NUM_OF_REPETITIONS*Chunk*2 - 1 : 0]  TestVectorDataIn      ; 
      RspFlit     [NUM_OF_REPETITIONS*Chunk*2 - 1 : 0]  TestVectorRspIn       ; 
      DataFlit    [NUM_OF_REPETITIONS*Chunk*2 - 1 : 0]  TestVectorDataOut     ; 
      int                                               CommandPointer        ;
      int                                               ReadReqPointer        ;
      int                                               WriteReqPointer       ;
      int                                               DataInPointer         ;
      int                                               RspInPointer          ;
      int                                               DataOutPointer        ;
      int                                               CountFinishedCommands ;
      int                                               lengthCountR      = 0 ;
      int                                               lengthCountW      = 0 ;
      reg         [BRAM_COL_WIDTH             - 1 : 0]  NextLengthCountR      ;
      reg         [BRAM_COL_WIDTH             - 1 : 0]  NextLengthCountW      ;
      
      
      //Check for Transmitions without Credits
      always_ff @ (posedge Clk)begin
        if(!RST) begin
          if((ReqChan     . TXREQFLITV &  CountReqCrdsOutb  == 0)|
             (RspOutbChan . TXRSPFLITV &  CountRspCrdsOutb  == 0)| 
             (DatOutbChan . TXDATFLITV &  CountDataCrdsOutb == 0)|
             (RspInbChan  . RXRSPFLITV &  CountRspCrdsInb   == 0)|
             (DatInbChan  . RXDATFLITV &  CountDataCrdsInb  == 0))
             $display("--Error : Transmition without credits. Crds: Req : %d,OutbRSP : %d,OutbData : %d, InbRSP: %d, InbData: %d",CountReqCrdsOutb,CountRspCrdsOutb,CountDataCrdsOutb,CountRspCrdsInb,CountDataCrdsInb);
        end
      end
      
      //Create TestVector
      always_ff@(posedge Clk) begin 
        if(RST) begin 
          TestVectorCommand     <= '{default : 0} ;
          TestVectorReadReq     <= '{default : 0} ;
          TestVectorWriteReq    <= '{default : 0} ;
          TestVectorDataIn      <= '{default : 0} ;
          TestVectorRspIn       <= '{default : 0} ;
          TestVectorDataOut     <= '{default : 0} ;
          ReadReqPointer        <= 0              ;
          WriteReqPointer       <= 0              ;
          DataInPointer         <= 0              ;
          RspInPointer          <= 0              ;
          DataOutPointer        <= 0              ;         
          CountFinishedCommands <= 0              ;  
          CommandPointer        <= 0              ;
        end
        else begin
          if(IssueValid & !CmdFIFOFULL)begin           // update a Command TestVector when insert a new command
            TestVectorCommand[CommandPointer] <= Command ;
            CommandPointer <= CommandPointer + 1 ;
          end
          if(ReqChan.TXREQFLITV & (ReqChan.TXREQFLIT.Opcode == `ReadOnce) & CountReqCrdsOutb != 0 )begin // update a Read TestVector when a new Read Req happens
            TestVectorReadReq[ReadReqPointer] <= ReqChan.TXREQFLIT ;
            ReadReqPointer <= ReadReqPointer + 1 ;
            uniqueReadTxnID(ReadReqPointer,ReqChan.TXREQFLIT);
          end
          if(ReqChan.TXREQFLITV & (ReqChan.TXREQFLIT.Opcode == `WriteUniquePtl) & CountReqCrdsOutb != 0 )begin // update a Write TestVector when a new Write Req happens
            TestVectorWriteReq[WriteReqPointer] <= ReqChan.TXREQFLIT ;
            WriteReqPointer <= WriteReqPointer + 1 ;
            uniqueWriteTxnID(WriteReqPointer,ReqChan.TXREQFLIT);
          end
          if(RspInbChan.RXRSPFLITV & CountRspCrdsInb != 0 )begin // update Rsp TestVector when a new Rsp comes 
            TestVectorRspIn[RspInPointer] <= RspInbChan.RXRSPFLIT ;
            RspInPointer <= RspInPointer + 1 ;
          end
          if(DatInbChan.RXDATFLITV & CountDataCrdsInb != 0 )begin    // update Data In TestVector when a new RspData comes 
            TestVectorDataIn[DataInPointer] <= DatInbChan.RXDATFLIT ;
            DataInPointer  <= DataInPointer + 1 ;
          end
          if(DatOutbChan.TXDATFLITV & CountDataCrdsOutb != 0 )begin // update Data Out TestVector when a new Data out Rsp Happens
            TestVectorDataOut[DataOutPointer] <= DatOutbChan.TXDATFLIT ;
            DataOutPointer <= DataOutPointer + 1 ;
          end
          if(UUT.SigDeqCommand)begin //Count finished Command Requests
            CountFinishedCommands <= CountFinishedCommands + 1;
          end
          if(CountFinishedCommands == NUM_OF_REPETITIONS & BS.EmptyCom)begin //When all commands are finished Check if every transaction happened ok
            CountFinishedCommands <= 0 ;
            printCheckList            ;
          end
        end
      end
        
      //task that checks if results are corect
      int j=0 ;
      task printCheckList ;
      begin
        #(period*2);
        ReadReqPointer  = 0;
        WriteReqPointer = 0;
        CommandPointer  = 0;
        $display("%d Command , SrcAddr : %d , DstAddr : %d , Length : %d",CommandPointer,TestVectorCommand[CommandPointer].SrcAddr,TestVectorCommand[CommandPointer].DstAddr,TestVectorCommand[CommandPointer].Length );
        while(CommandPointer != NUM_OF_REPETITIONS)  begin // for every command in BS check
          //for every Transaction of a command
            //if a ReadOnce Read Req happens with corect Addr and a corect Data Rsp came with corect TxnID and Opcode then print corect
            if(lengthCountR != TestVectorCommand[CommandPointer].Length)begin
              if((TestVectorReadReq[ReadReqPointer].Opcode == `ReadOnce) & (TestVectorDataIn[ReadReqPointer].Opcode == `CompData) & (TestVectorDataIn[ReadReqPointer].TxnID == (TestVectorReadReq[ReadReqPointer].TxnID)) & (TestVectorReadReq[ReadReqPointer].Addr == (TestVectorCommand[CommandPointer].SrcAddr + lengthCountR)-((TestVectorCommand[CommandPointer].SrcAddr + lengthCountR)%CHI_DATA_WIDTH)))
                $write("\n %d : Correct Read Trans",j);
              // if Wrong Read Opcode print Error
              else if(TestVectorReadReq[ReadReqPointer].Opcode != `ReadOnce)begin
                $display("\n--ERROR :: ReadReq Opcode is not ReadOnce , TxnID : %d",TestVectorReadReq[ReadReqPointer].TxnID);
                $stop;
              end
              // if Wrong Data Rsp Opcode print Error
              else if(TestVectorDataIn[ReadReqPointer].Opcode != `CompData)begin
                $display("\n--ERROR :: DataRsp Opcode is not CompData , TxnID : %d",TestVectorReadReq[ReadReqPointer].TxnID);
                $stop;
              end
              //if wrong Address
              else if((TestVectorReadReq[ReadReqPointer].Addr != (TestVectorCommand[CommandPointer].SrcAddr + lengthCountR-((TestVectorCommand[CommandPointer].SrcAddr + lengthCountR)%CHI_DATA_WIDTH))))begin
                $display("\n--ERROR ::Wrong Used Addr :%d. Addr :%d should be used",TestVectorWriteReq[ReadReqPointer].Addr ,(TestVectorCommand[CommandPointer].SrcAddr + lengthCountR)-((TestVectorCommand[CommandPointer].SrcAddr + lengthCountR)%CHI_DATA_WIDTH));
                $stop;
              end
              // if Wrong Data Rsp TxnID print Error
              else begin
                $display("\n--ERROR :: DataRsp TxnID :%d is not the same with ReadReq TxnID :%d",TestVectorDataIn[ReadReqPointer].TxnID ,TestVectorReadReq[ReadReqPointer].TxnID);
                $stop;
              end
              ReadReqPointer = ReadReqPointer + 1;
            end
            else 
              $write("\n                                 ");
            
            if(lengthCountW != TestVectorCommand[CommandPointer].Length)begin
              // if corect opcode and Addr of a Write Req and corect opcode TxnID of a DBID Rsp and corect Data Out Rsp opcode ,TxnID and BE then print corect
              if((TestVectorWriteReq[WriteReqPointer].Opcode == `WriteUniquePtl & (TestVectorWriteReq[WriteReqPointer].Addr == (TestVectorCommand[CommandPointer].DstAddr + lengthCountW)-((TestVectorCommand[CommandPointer].DstAddr + lengthCountW)%CHI_DATA_WIDTH))
              &(((TestVectorRspIn[WriteReqPointer].Opcode == `DBIDResp) | (TestVectorRspIn[WriteReqPointer].Opcode == `CompDBIDResp)) & (TestVectorRspIn[WriteReqPointer].TxnID == (TestVectorWriteReq[WriteReqPointer].TxnID)))
              &((TestVectorDataOut[WriteReqPointer].Opcode == `NonCopyBackWrData) & (TestVectorRspIn[WriteReqPointer].DBID == TestVectorDataOut[WriteReqPointer].TxnID))))
                  $write("%d Correct Write Trans",j); // Corect
              // Wrong Write Opcode
              else if(TestVectorWriteReq[WriteReqPointer].Opcode != `WriteUniquePtl)begin
                $display("\n--ERROR :: WriteReq Opcode is not WriteUniquePtl");
                $stop;
              end
              //wrong Address
              else if (TestVectorWriteReq[WriteReqPointer].Addr != (TestVectorCommand[CommandPointer].DstAddr + lengthCountW)-((TestVectorCommand[CommandPointer].DstAddr + lengthCountW)%CHI_DATA_WIDTH))begin
               $display("\n--ERROR ::Wrong Used Addr :%d. Addr :%d should be used",TestVectorReadReq[WriteReqPointer].Addr ,(TestVectorCommand[CommandPointer].DstAddr + lengthCountW)-((TestVectorCommand[CommandPointer].DstAddr + lengthCountW)%CHI_DATA_WIDTH));
                $stop;
              end
              // Wrong DBID Rsp Opcode
              else if(TestVectorRspIn[WriteReqPointer].Opcode != `DBIDResp & TestVectorRspIn[WriteReqPointer].Opcode != `CompDBIDResp )begin
                $display("\n--ERROR :: DataRsp Opcode is not DBIDResp or CompDBIDResp");
                $stop;
              end
              // Wrong TxnID Rsp Opcode
              else if(TestVectorRspIn[WriteReqPointer].TxnID != (TestVectorWriteReq[WriteReqPointer].TxnID)) begin
                $display("\n--ERROR :: DBIDRsp TxnID :%d is not the same with WriteReq TxnID :%d",TestVectorRspIn[WriteReqPointer].TxnID ,TestVectorWriteReq[WriteReqPointer].TxnID);
                $stop;
              end
              // Wrong Data Out Opcode
              else if(TestVectorDataOut[WriteReqPointer].Opcode != `NonCopyBackWrData) begin
                $display("\n--ERROR :: Data In Opcode is not NonCopyBackWrData");
                $stop;
              end
              // Wrong Data Out TxnID
              else begin
                $display("\n--ERROR :: DBIDRsp DBID :%d is not the same with Data Out DBID :%d",TestVectorRspIn[WriteReqPointer].DBID , TestVectorDataOut[WriteReqPointer].TxnID);
                $stop;
              end
              WriteReqPointer = WriteReqPointer + 1 ;
            end
           
           // update the number of transfered data of a coomand
            NextLengthCountR  = (lengthCountR == 0) ? ((TestVectorCommand[CommandPointer].Length <(CHI_DATA_WIDTH - TestVectorCommand[CommandPointer].SrcAddr[$clog2(CHI_DATA_WIDTH) - 1 : 0])) ? (TestVectorCommand[CommandPointer].Length) : (CHI_DATA_WIDTH - TestVectorCommand[CommandPointer].SrcAddr[$clog2(CHI_DATA_WIDTH) - 1 : 0])) : ((lengthCountR + CHI_DATA_WIDTH < TestVectorCommand[CommandPointer].Length) ? (lengthCountR + CHI_DATA_WIDTH) : (TestVectorCommand[CommandPointer].Length)) ;
            NextLengthCountW  = (lengthCountW == 0) ? ((TestVectorCommand[CommandPointer].Length <(CHI_DATA_WIDTH - TestVectorCommand[CommandPointer].DstAddr[$clog2(CHI_DATA_WIDTH) - 1 : 0])) ? (TestVectorCommand[CommandPointer].Length) : (CHI_DATA_WIDTH - TestVectorCommand[CommandPointer].DstAddr[$clog2(CHI_DATA_WIDTH) - 1 : 0])) : ((lengthCountW + CHI_DATA_WIDTH < TestVectorCommand[CommandPointer].Length) ? (lengthCountW + CHI_DATA_WIDTH) : (TestVectorCommand[CommandPointer].Length)) ;
  
            // update command read Requested Bytes
            if((NextLengthCountR == TestVectorCommand[CommandPointer].Length) &(NextLengthCountW == TestVectorCommand[CommandPointer].Length)) begin
              lengthCountR = 0 ;
            end
            else if(NextLengthCountR <= TestVectorCommand[CommandPointer].Length)begin
              lengthCountR = NextLengthCountR ;
            end
            
            // update command write Requested Bytes
            if((NextLengthCountR == TestVectorCommand[CommandPointer].Length) & (NextLengthCountW == TestVectorCommand[CommandPointer].Length)) begin
              lengthCountW = 0 ;
              CommandPointer = CommandPointer + 1;
              if(CommandPointer < NUM_OF_REPETITIONS)begin
                $display("\n\n %d Command , SrcAddr : %d , DstAddr : %d , Length : %d",CommandPointer,TestVectorCommand[CommandPointer].SrcAddr,TestVectorCommand[CommandPointer].DstAddr,TestVectorCommand[CommandPointer].Length );
              end
            end
            else if(NextLengthCountW <= TestVectorCommand[CommandPointer].Length)begin
              lengthCountW = NextLengthCountW ; end
          
            j++;
        end
        $display("\n---------THE END-------------");
      end
      endtask ;
      
      // Function that checks if used Read TxnID is unique
       function void uniqueReadTxnID;
       input int j; 
       input ReqFlit TVReadReq;
        if(j!=0) begin // If more than one Req
          for( int k = 0 ; k < j ; k++)begin
            // if there is an earlier uncomplete Read or Write transaction with the same TxnID print error
            if((TVReadReq.TxnID == TestVectorReadReq[k].TxnID & TestVectorDataIn[k] == 0) | (TVReadReq.TxnID == TestVectorWriteReq[k].TxnID  & TestVectorRspIn[k] == 0 & TestVectorWriteReq[k]!=0))begin
              $display("\n--Error :: In ReadReq TxnID -> %d is already used",TVReadReq.TxnID);
              $stop;
              return;
            end
          end
        end
      endfunction
      
      // Function that checks if used Write TxnID is unique
      function void uniqueWriteTxnID(input int j , input ReqFlit TVWriteReq);
        if(j!=0)begin // If more than one Req
          for( int k = 0 ; k < j ; k++)begin
            // if there is an earlier uncomplete Read or Write transaction with the same TxnID print error
            if((TVWriteReq.TxnID == TestVectorWriteReq[k].TxnID & TestVectorRspIn[k] == 0) | (TVWriteReq.TxnID == TestVectorReadReq[k].TxnID & TestVectorDataIn[k] == 0 & TestVectorReadReq[k] != 0))begin
              $display("\n--Error :: In WriteReq TxnID -> %d is already used",TVWriteReq.TxnID );
              $stop;
              return;
            end
          end
        end
      endfunction
    
endmodule