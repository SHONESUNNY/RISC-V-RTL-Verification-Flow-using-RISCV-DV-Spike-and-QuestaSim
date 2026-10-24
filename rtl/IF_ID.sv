`timescale 1ns / 1ps

module IF_ID(input StallD ,input FlushD, input clk, input [31:0] PCF ,input[31 :0] PCPlus4F ,
 input Valid_F ,input logic [31:0] Instr_F ,input logic rst ,
 output logic [31:0] InstrD ,output logic [31:0] PCD, output logic [31:0] PCPlus4D , output logic Valid_D);
 
 always @(posedge clk)begin  
  if(rst)begin   
   PCD <= 32'b0;
   PCPlus4D <= 32'b0;
   InstrD <= 32'h00000013;
   Valid_D <= 1'b0;
    end
    else if (FlushD)begin
    PCD <= 32'b0;
    PCPlus4D <= 32'b0;
    InstrD <= 32'h00000013;
    Valid_D <= 1'b0;
    end
    else if(~StallD)begin
    PCD <= PCF ;
    PCPlus4D <= PCPlus4F ;
    InstrD <= Instr_F ;
    Valid_D <= Valid_F ;
    end
end
 
 
 endmodule