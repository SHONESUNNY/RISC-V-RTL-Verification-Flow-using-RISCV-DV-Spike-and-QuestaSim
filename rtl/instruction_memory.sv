`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08.07.2026 00:07:06
// Design Name: 
// Module Name: memory
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Cre
module instruction_memory (
    input  wire [31:0] addr,
    output wire [31:0] instr
);

    reg [31:0] mem [0:65535];

    wire [31:0] index;
    assign index = (addr - 32'h80000000) >> 2;

    initial begin
        $display("Loading instruction memory...");
        $readmemh("hexfile.txt", mem);
    end

    assign instr = mem[index];

endmodule
