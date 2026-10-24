`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07.07.2026 01:37:08
// Design Name: 
// Module Name: ALU
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



module ALU(input [31:0] SrcAE,input [31:0] SrcBE,input [3:0] ALUControlE,
output reg [31:0] ALUResultE
,output reg ZeroE
    );
    always@(*)begin
    case(ALUControlE)
4'b0000: ALUResultE = SrcAE + SrcBE;                       // ADD
4'b0001: ALUResultE = SrcAE - SrcBE;                       // SUB
4'b0010: ALUResultE = SrcAE & SrcBE;                       // AND
4'b0011: ALUResultE = SrcAE | SrcBE;                       // OR
4'b0100: ALUResultE = SrcAE ^ SrcBE;                       // XOR
4'b0101: ALUResultE = SrcAE << SrcBE[4:0];                // SLL
4'b0110: ALUResultE = SrcAE >> SrcBE[4:0];                // SRL
4'b0111: ALUResultE = $signed(SrcAE) >>> SrcBE[4:0];       // SRA
4'b1000: ALUResultE = ($signed(SrcAE) < $signed(SrcBE));   // SLT
4'b1001: ALUResultE = (SrcAE < SrcBE);
    default:ALUResultE = 32'b0;   
    endcase
    ZeroE  =  (ALUResultE == 1'b1);

    end
endmodule

module alu_decoder(
    input logic [6:0] op,
    input logic [2:0] funct3D,
    input logic funct7_5,
    output logic [3:0] ALUControlE
);
 
 typedef enum logic [3:0]{
    ALU_ADD  = 4'b0000,
    ALU_SUB  = 4'b0001,
    ALU_AND  = 4'b0010,
    ALU_OR   = 4'b0011,
    ALU_XOR  = 4'b0100,
    ALU_SLL  = 4'b0101,
    ALU_SRL  = 4'b0110,
    ALU_SRA  = 4'b0111,
    ALU_SLT  = 4'b1000,
    ALU_SLTU = 4'b1001
    }alu_op ;
    
 always_comb begin        
   ALUControlE = ALU_ADD;

  case(op)
    //R-Type 
    7'b0110011: begin
      case (funct3D)
        3'b000: if(funct7_5)begin
                  ALUControlE = ALU_SUB ;
                 end else begin 
                   ALUControlE = ALU_ADD; 
                   end
        3'b111: ALUControlE = ALU_AND;
        3'b110: ALUControlE = ALU_OR;
        3'b100: ALUControlE = ALU_XOR;
        3'b001: ALUControlE = ALU_SLL;
        3'b101: ALUControlE = (funct7_5)? ALU_SRA: ALU_SRL;
        3'b010: ALUControlE = ALU_SLT;
        3'b011: ALUControlE = ALU_SLTU;

         default: ALUControlE = ALU_ADD;
         endcase
        end
        
    //I-type 
     7'b0010011: begin

          case(funct3D)
                3'b000: ALUControlE = ALU_ADD;   // ADDI
                3'b111: ALUControlE = ALU_AND;   // ANDI
                3'b110: ALUControlE = ALU_OR;    // ORI
                3'b100: ALUControlE = ALU_XOR;   // XORI
                3'b010: ALUControlE = ALU_SLT;   // SLTI
                3'b011: ALUControlE = ALU_SLTU;  // SLTIU
                3'b001: ALUControlE = ALU_SLL;   // SLLI
                3'b101: ALUControlE =  (funct7_5)? ALU_SRA: ALU_SRL;

                default: ALUControlE = ALU_ADD;

           endcase
           end
     endcase   
   end 
endmodule
