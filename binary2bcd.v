`timescale 1ns / 1ps
module binary2bcd (
    input clk,
    input reset,
    input start,
    input [13:0] in,       // 14-bit binary input
    output reg [3:0] bcd3, // Thousands place
    output reg [3:0] bcd2, // Hundreds place
    output reg [3:0] bcd1, // Tens place
    output reg [3:0] bcd0, // Ones place
    output reg [3:0] count, // Tracks the bit-shifting process
    output reg [1:0] state // Current FSM state
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam LOAD = 2'b01;
    localparam CONVERT = 2'b10;
    localparam CONVERT_shift = 2'b11;

    // Internal registers
    reg [29:0] shift_reg; // 14 bits input + 4x4 for BCD digits
    reg [4:0] bit_count;  // Counter for shift iterations

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            // Reset everything
            bcd3 <= 4'd0;
            bcd2 <= 4'd0;
            bcd1 <= 4'd0;
            bcd0 <= 4'd0;
            count <= 4'd0;
            shift_reg <= 28'd0;
            bit_count <= 5'd0;
            state <= IDLE;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= LOAD;
                    end
                end
                LOAD: begin
                    // Load input and reset counters
                    shift_reg <= {16'b0, in};
                    bit_count <= 15; // Start with the MSB of the input
                    state <= CONVERT;
                end
                CONVERT: begin
                    // Perform binary to BCD conversion using shift-add-3 algorithm
                    shift_reg[29:26] <= (shift_reg[29:26] >= 5) ? shift_reg[29:26] + 3 : shift_reg[29:26];
                    shift_reg[25:22] <= (shift_reg[25:22] >= 5) ? shift_reg[25:22] + 3 : shift_reg[25:22];
                    shift_reg[21:18] <= (shift_reg[21:18] >= 5) ? shift_reg[21:18] + 3 : shift_reg[21:18];
                    shift_reg[17:14] <= (shift_reg[17:14] >= 5) ? shift_reg[17:14] + 3 : shift_reg[17:14];
                    
                    if(bit_count > 0) begin
                        state <= CONVERT_shift;
                    end else begin
                        // If all bits are processed, finalize
                        bcd3 <= (shift_reg[29:26] < 10) ? shift_reg[29:26] : 0;
                        bcd2 <= (shift_reg[25:22] < 10 ) ? shift_reg[25:22] : 0;
                        bcd1 <= (shift_reg[21:18] < 10 ) ? shift_reg[21:18] : 0;
                        bcd0 <= (shift_reg[17:14] < 10) ? shift_reg[17:14] : 0;
                        state <= IDLE;
                    end      
                    
                end
                CONVERT_shift : begin
                

                        // Shift left by one bit
                        shift_reg <= shift_reg<<1;
    
                        bit_count <= bit_count - 1;
    
                        // Increment count for testbench visibility
                        count <= count + 1;
                        
                        state <= CONVERT;


                end
                default: state <= IDLE; // Default state
            endcase
        end
    end
endmodule


`timescale 1ns / 1ps

module tb_binary2bcd;

    // Inputs
    reg clk;
    reg reset;
    reg start;
    reg [13:0] in;

    // Outputs
    wire [3:0] bcd3;
    wire [3:0] bcd2;
    wire [3:0] bcd1;
    wire [3:0] bcd0;
    wire [3:0] count;
    wire [1:0] state;

    // Instantiate the Unit Under Test (UUT)
    binary2bcd uut (
        .clk(clk),
        .reset(reset),
        .start(start),
        .in(in),
        .bcd3(bcd3),
        .bcd2(bcd2),
        .bcd1(bcd1),
        .bcd0(bcd0),
        .count(count),
        .state(state)
    );

    // Clock generation
    always begin
        clk = 1'b0;
        #5 clk = 1'b1;
        #5;
    end

    // Stimulus block
    initial begin
        // Initialize Inputs
        reset = 0;
        start = 0;
        in = 14'b0;

        // Apply reset
        reset = 1;
        #10;
        reset = 0;

        // Test 1: Convert a binary number to BCD
        in = 14'd1234; // Binary number 1234
        start = 1;
        #10;
        start = 0;
        
        // Wait for the conversion to complete
        #100;

        // Test 2: Convert another binary number to BCD
        in = 14'd5678; // Binary number 5678
        start = 1;
        #10;
        start = 0;
        
        // Wait for the conversion to complete
        #100;

        // Test 3: Convert another binary number to BCD
        in = 14'd4321; // Binary number 4321
        start = 1;
        #10;
        start = 0;

        // Wait for the conversion to complete
        #100;

        // End of simulation
        $finish;
    end

    // Monitor output values
    initial begin
        $monitor("Time: %t, In: %d, BCD3: %d, BCD2: %d, BCD1: %d, BCD0: %d, Count: %d, State: %b", 
                 $time, in, bcd3, bcd2, bcd1, bcd0, count, state);
    end

endmodule


