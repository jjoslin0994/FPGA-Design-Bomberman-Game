`timescale 1ns / 1ps

module LFSR_16(
    input clk,
    input rst,
    input w_en,
    input [15:0] w_in,
    output reg [15:0] out
    );
    
    reg [15:0] count;
    
    // Feedback taps for maximal-length LFSR
    wire feedback;

    // XOR feedback based on specific taps for a 16-bit maximal-length LFSR
    assign feedback = w_in[15] ^ w_in[13] ^ w_in[12] ^ w_in[10];

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // Reset the LFSR to a predefined seed (non-zero)
            out <= 16'hA5A5; // Example seed value
        end else if (w_en) begin

            // Update LFSR output based on feedback and shift
            if(count[7]) begin
                out <= count;
            end else begin
                out <= {w_in[14:0], feedback};
            end
        end else begin
            count <= count + 1;
        end
    end

endmodule
