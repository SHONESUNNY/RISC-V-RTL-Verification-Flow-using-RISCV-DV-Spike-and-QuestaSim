`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12.07.2026 22:46:03
// Design Name: 
// Module Name: result_mux
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



module result_mux(input [31:0]ALUResultW,input [31:0] ReadDataW,input [31:0]PCPlus4W,
input [1:0]ResultSrcW,
output reg [31:0]ResultW

    );
    always@(*)begin
    case(ResultSrcW)
    2'b00:ResultW = ALUResultW ;
    2'b01:ResultW = ReadDataW;
    2'b10:ResultW = PCPlus4W;
    default: ResultW = ALUResultW;
    endcase
    end
endmodule
