`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12.07.2026 22:51:09
// Design Name: 
// Module Name: branch_target
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

module branch_target (
    input  [31:0] PCE,
    input  [31:0] ImmExtE,
    output [31:0] PCTargetE,
    input [31:0]ALUResultE,
    input Branch_Target_selE
);
    
    assign PCTargetE = (Branch_Target_selE) ? (PCE + ImmExtE) : (ALUResultE & ~32'h1);
endmodule

