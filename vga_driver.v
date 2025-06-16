`timescale 1ns / 1ps

module vga_driver(
    input clk, reset,
    
    output reg h_sync,
    output reg v_sync,
    
    output wire display_on, px_clk,
    output reg [9:0] x_pos, y_pos
    );
    
    localparam HSYNC_PULSE = 96;
    localparam HSYNC_FP = 16;
    localparam HSYNC_BP = 48;
    localparam HSYNC_PIX = 800;
    
    localparam VSYNC_PULSE = 2;
    localparam VSYNC_FP = 10;
    localparam VSYNC_BP = 29;
    localparam VSYNC_PIX = 521;
    
    initial begin
        h_count = 0;
        v_count = 0;
        
        h_sync = 0;
        v_sync = 0;
    end
    
   reg [9:0] h_count, v_count;
       
    
assign display_on = (h_count >= (HSYNC_PULSE + HSYNC_BP) && h_count < (HSYNC_PULSE + HSYNC_BP + 640) &&
                     v_count >= (VSYNC_PULSE + VSYNC_BP) && v_count < (VSYNC_PULSE + VSYNC_BP + 480)) ? 1 : 0;

    
  // Clock divider for pixel clock (px_clk)
    px_clk PX_CLK(
        .clk(clk),
        .px_clk(px_clk)
    );
    
    // pixel counters
    always @ (posedge px_clk) begin
        if(h_count == HSYNC_PIX - 1) begin
            v_count <= (v_count + 1) % VSYNC_PIX;
            h_count <= 0;
        end else begin
            h_count <= h_count + 1;
        end
    end
    
   // Generate horizontal sync pulse
    always @ (posedge px_clk) begin
        if (h_count < HSYNC_PULSE) begin
            h_sync <= 1'b0;
        end else begin
            h_sync <= 1'b1;
        end
    end
    
    // Generate vertical sync pulse
    always @ (posedge px_clk) begin
        if (v_count < VSYNC_PULSE) begin
            v_sync <= 1'b0;
        end else begin
            v_sync <= 1'b1;
        end
    end
    
always @(posedge px_clk) begin
    // Check if within the image display region
    if ((h_count >= (HSYNC_PULSE + HSYNC_BP ) && h_count < (HSYNC_PULSE + HSYNC_BP + 640)) && 
        (v_count >= (VSYNC_PULSE + VSYNC_BP) && v_count < (VSYNC_PULSE + VSYNC_BP + 480))) begin
        if (x_pos == 639) begin  // Include the 527th pixel
            x_pos <= 0;
            y_pos <= (y_pos + 1) % 480;
        end else begin
            x_pos <= x_pos + 1;
        end
    end else if (h_count == 0 && v_count == 0) begin
        // Reset to the top-left corner of the image at the start of each new frame
        x_pos <= 0;
        y_pos <= 0;
    end
end


    
    
    
endmodule
