`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08.07.2026 21:52:35
// Design Name: 
// Module Name: pc_logic
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


module pc_logic(input clk,input StallF,input PCSrcE,
output reg [31:0]PCF,input[31:0] PCTargetE
,input rst ,input mret_redirect,input [31:0] mepc,input trap_redirect,
input [31:0] mtvec
    );
    always @(posedge clk)begin
    if (rst )begin
    PCF <= 32'h80000000;
    end else if (trap_redirect)
    PCF <= mtvec;
    else if (mret_redirect)
    PCF <= mepc;
    else if(~StallF)begin
    if (PCSrcE)
    PCF <= PCTargetE;
    else
    PCF <= PCF+4;
    end
    end
endmodule

