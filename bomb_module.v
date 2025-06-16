module bomb_module
(
   input wire clk, reset,
   input wire [9:0] x_a, y_a,                       // current pixel location on screen
   input wire [1:0] cd,                             // bomberman current direction
   input wire [9:0] x_b, y_b,                       // bomberman coordinates in abm
   input wire A,                                    // bomb button input
   input wire gameover,                             // signal from game_lives module, asserted when gameover
   input wire bomberman_on,
output wire [11:0] bomb_rgb, exp_rgb, powerup_rgb,   // rgb output for bomb and explosion tiles
   output wire bomb_on, exp_on,                     // signals asserted when vga x/y pixels are within bomb or explosion tiles on screen
   output wire powerup_on,                          // signal asserted when scanner on power up 
   output wire [9:0] block_w_addr,                  // adress into block map RAM of where explosion is to clear block
   output wire block_we,                            // write enable signal into block map RAM
   output wire post_exp_active,                      // signal asserted when bomb_exp_state_reg == post_exp, bomb is active on screen
   output wire [15:0] speed_up
   //output led
);

localparam BM_HB_OFFSET_9 = 8;             // offset from top of sprite down to top of 16x16 hit box  
localparam BM_HB_HALF     = 8;             // half length of bomberman hitbox

localparam X_WALL_L = 48;                  // end of left wall x coordinate
localparam X_WALL_R = 576;                 // begin of right wall x coordinate
localparam Y_WALL_U = 32;                  // bottom of top wall y coordinate
localparam Y_WALL_D = 448;                 // top of bottom wall y coordinate

localparam BOMB_COUNTER_MAX = 220000000;   // max values for counters used for bomb and explosion timing
localparam EXP_COUNTER_MAX  = 120000000;

// symbolic state declarations
localparam [3:0] no_bomb  = 3'b000,  // no bomb on screen
                 bomb     = 3'b001,  // bomb on screen for 1.5 s
                 exp_1    = 3'b010,  // take care of explostion tile 1
                 exp_2    = 3'b011,  // 2
                 exp_3    = 3'b100,  // 3
                 exp_4    = 3'b101,  // 4
                 post_exp = 3'b110;  // wait for .75 s to finish
                 
// explosion powerup always block;

                         
          
reg [3:0] bomb_exp_state_reg;
wire [3:0] bomb_exp_state_next;   // FSM register and next-state logic
reg [5:0] bomb_x_reg, bomb_y_reg;                    // bomb ABM coordinate location register 
wire [5:0] bomb_x_next, bomb_y_next;                  // and next-state logic
wire bomb_active;             // register asserted when bomb is on screen
wire exp_active;               // register asserted when explosion is active on screen.
reg [9:0] exp_block_addr_reg;
wire [9:0] exp_block_addr_next;   // address to write a 0 to block map to clear a block hit by explosion.
reg block_we_reg;
wire block_we_next;                     // register to enable block map RAM write enable
reg  [27:0] bomb_counter_reg;                        // counter register to track how long a bomb exists before exploding
wire [27:0] bomb_counter_next;
reg  [26:0] exp_counter_reg;                         // counter register to track how long an explosion lasts
wire [26:0] exp_counter_next;

// x/y bomb coordinates translated to arena coordinates
wire [9:0] x_bomb_a, y_bomb_a;
assign x_bomb_a = x_b + BM_HB_HALF - X_WALL_L; 
assign y_bomb_a = y_b + BM_HB_HALF + BM_HB_OFFSET_9 - Y_WALL_U;
assign block_we_next = bomb_exp_state_reg == exp_1 || bomb_exp_state_reg == exp_2 || bomb_exp_state_reg == exp_3 || bomb_exp_state_reg == exp_4;

assign exp_block_addr_next = (bomb_exp_state_reg == exp_1) ? (bomb_x_reg-1 + bomb_y_reg * 33) :
                             (bomb_exp_state_reg == exp_2) ? (bomb_x_reg+1 + bomb_y_reg * 33) :
                             (bomb_exp_state_reg == exp_3) ? (bomb_x_reg + (bomb_y_reg-1) * 33) :
                             (bomb_exp_state_reg == exp_4) ? (bomb_x_reg + (bomb_y_reg+1) * 33) : 
                             0 ;



// infer bomb counter register
always @(posedge clk, posedge reset)
   if(reset)
      bomb_counter_reg <= 0;
   else
      bomb_counter_reg <= bomb_counter_next;

assign led = bomb_exp_state_reg == post_exp;
assign bomb_active = bomb_exp_state_reg == bomb;
assign exp_active = (bomb_exp_state_reg == exp_1) || (bomb_exp_state_reg == exp_2) || (bomb_exp_state_reg == exp_3) || (bomb_exp_state_reg == exp_4) || (bomb_exp_state_reg == post_exp );
assign post_exp_active = bomb_exp_state_reg == post_exp;

assign bomb_x_next = (A && bomb_exp_state_reg == no_bomb) ? x_bomb_a[9:4] : bomb_x_reg;
assign bomb_y_next = (A && bomb_exp_state_reg == no_bomb) ? y_bomb_a[9:4]  : bomb_y_reg;

assign bomb_exp_state_next = 
        (A && bomb_exp_state_reg == no_bomb) ? bomb :                                   // Add bomb
        (bomb_counter_reg == BOMB_COUNTER_MAX && bomb_exp_state_reg == bomb) ? exp_1 :  // Transition to explosion
        ((bomb_exp_state_reg == exp_1 || bomb_exp_state_reg == exp_2 || 
        bomb_exp_state_reg == exp_3 || bomb_exp_state_reg == exp_4) &&
        exp_counter_reg == 24000000) ? bomb_exp_state_reg + 1 :                       // Progress explosion states
        (bomb_exp_state_reg == post_exp && exp_counter_reg == 24000000) ? no_bomb :     // Return to no bomb
        bomb_exp_state_reg;                                                             // Hold current state

                             
   
                             
// bomb counter next-state logic: if bomb is active and counter < max, count up.
assign bomb_counter_next = (bomb_active & bomb_counter_reg < BOMB_COUNTER_MAX) ? bomb_counter_reg + 1 : 0;

// infer explosion counter register
always @(posedge clk, posedge reset)
   if(reset)
      exp_counter_reg <= 0;
   else
      exp_counter_reg <= exp_counter_next;
      
// explosion counter next-state logic: is explosion active and counter < max, count up
assign exp_counter_next = (exp_active & exp_counter_reg < 24000000) ? exp_counter_reg + 1 : 0;

// infer registers used in FSM
always @(posedge clk, posedge reset)
   if(reset)
      begin
      bomb_exp_state_reg <= no_bomb;
      bomb_x_reg         <= 0;
      bomb_y_reg         <= 0;
      exp_block_addr_reg <= 0;
      block_we_reg       <= 0;
      end
   else
      begin
      bomb_exp_state_reg <= bomb_exp_state_next;
      bomb_x_reg         <= bomb_x_next;
      bomb_y_reg         <= bomb_y_next;
      exp_block_addr_reg <= exp_block_addr_next;
      block_we_reg       <= block_we_next;
      end

wire block_on;
wire [5:0] sprite_offset;
wire [11:0] exploding_block_rgb;
assign sprite_offset = (bomb_exp_state_reg < 3) ? 16 : (bomb_exp_state_reg < 4) ? 32 : (bomb_exp_state_reg < 5) ? 48 : 64;

assign exp_rgb = (block_on) ? exploding_block_rgb : exp_rgb_fire ;


block_distruction_dm destruction_unit(
    .a((x_a[3:0]) + {(y_a[3:0] + sprite_offset), 4'd0}),
    .spo(exploding_block_rgb)
);


      
block_map block_map_copy(
    .a(block_w_addr), 
    .d(1'b0), 
    .dpra(x_a[9:4] + y_a[9:4]*33), 
    .clk(clk), 
    .we(block_we_reg), 
    .spo(), 
    .dpo(data_out)
    );
assign block_on = data_out;    
      
       
// bomb_on asserted when bomb x/y arena block map coordinates equal that of x/y ABM coordinates and bomb is active
assign bomb_on = (x_a[9:4] == bomb_x_reg & y_a[9:4] == bomb_y_reg & bomb_active);

// explosion_on asserted when appropriate tile location with respect to bomb ABM coordinates matches
// x/y ABM coordinates
assign exp_on = (exp_active &(
                (                   x_a[9:4] == bomb_x_reg   & y_a[9:4] == bomb_y_reg  ) |  // center
                (bomb_x_reg != 0  & x_a[9:4] == bomb_x_reg-1 & y_a[9:4] == bomb_y_reg  ) |  // exp_1
                (bomb_x_reg != 32 & x_a[9:4] == bomb_x_reg+1 & y_a[9:4] == bomb_y_reg  ) |  // exp_2
                (bomb_y_reg != 0  & x_a[9:4] == bomb_x_reg   & y_a[9:4] == bomb_y_reg-1) |  // exp_1
                (bomb_y_reg != 26 & x_a[9:4] == bomb_x_reg   & y_a[9:4] == bomb_y_reg+1) |
                (bomb_x_reg - extra_radius_coutner_q >= 0  & x_a[9:4] == bomb_x_reg-extra_radius_coutner_q & y_a[9:4] == bomb_y_reg  ) |
                (bomb_x_reg + extra_radius_coutner_q <= 32  & x_a[9:4] == bomb_x_reg-extra_radius_coutner_q & y_a[9:4] == bomb_y_reg  ) | 
                (bomb_y_reg - extra_radius_coutner_q >= 0  & x_a[9:4] == bomb_x_reg   & y_a[9:4] == bomb_y_reg-extra_radius_coutner_q) |
                (bomb_y_reg + extra_radius_coutner_q <= 26  & x_a[9:4] == bomb_x_reg   & y_a[9:4] == bomb_y_reg+extra_radius_coutner_q)
                )); // exp_2
                

                 
wire [9:0] exp_addr = (                   x_a[9:4] == bomb_x_reg   & y_a[9:4] == bomb_y_reg  ) ? x_a[3:0] + (y_a[3:0] << 4)                                             : // center
                      (bomb_x_reg != 0  & x_a[9:4] == bomb_x_reg-1 & y_a[9:4] == bomb_y_reg  ) ? (15 - x_a[3:0]) + ((y_a[3:0] + 16) << 4)                               : // exp_1 left
                      (bomb_x_reg != 32 & x_a[9:4] == bomb_x_reg+1 & y_a[9:4] == bomb_y_reg  ) ? x_a[3:0] + ((y_a[3:0] + 16) << 4)                                      : // exp_2 right
                      (bomb_y_reg != 0  & x_a[9:4] == bomb_x_reg   & y_a[9:4] == bomb_y_reg-1) ? x_a[3:0] + ((y_a[3:0] + 32) << 4)                                      : // exp_3 down
                      (bomb_y_reg != 26 & x_a[9:4] == bomb_x_reg   & y_a[9:4] == bomb_y_reg+1) ? x_a[3:0] + (((15 - y_a[3:0]) + 32) << 4)                               :  // exp_4 up
                      (bomb_x_reg - extra_radius_coutner_q >= 0  & x_a[9:4] == bomb_x_reg-extra_radius_coutner_q & y_a[9:4] == bomb_y_reg) ?  (15 - x_a[3:0]) + ((y_a[3:0] + 16) << 4) :
                      (bomb_x_reg + extra_radius_coutner_q <= 32  & x_a[9:4] == bomb_x_reg-extra_radius_coutner_q & y_a[9:4] == bomb_y_reg) ? x_a[3:0] + ((y_a[3:0] + 16) << 4) :
                      (bomb_y_reg - extra_radius_coutner_q >= 0  & x_a[9:4] == bomb_x_reg & y_a[9:4] == bomb_y_reg-extra_radius_coutner_q) ? x_a[3:0] + ((y_a[3:0] + 32) << 4) :
                      (bomb_y_reg + extra_radius_coutner_q <= 26  & x_a[9:4] == bomb_x_reg   & y_a[9:4] == bomb_y_reg+extra_radius_coutner_q) ? x_a[3:0] + (((15 - y_a[3:0]) + 32) << 4)
                      : 0;        
                      
                      
// instantiate bomb sprite ROM
bomb_dm bomb_dm_unit(
    .a((x_a[3:0]) + {y_a[3:0], 4'd0}), 
    .spo(bomb_rgb));
wire [11:0] exp_rgb_fire;
// instantiate explosions sprite ROM
explosions_br exp_br_unit(
                            .clka(clk), 
                            .ena(1'b1), 
                            .addra(exp_addr), 
                            .douta(exp_rgb_fire)
                            );

// assign explosion block map write address to output
assign block_w_addr = exp_block_addr_reg;

// assign block map write enable to output
assign block_we = block_we_reg;


wire [15:0] random_16_seed;
assign random_16_seed = (7 * (x_b+y_b)) & 16'hFFFF; // base random seed off player locaton to guarantee a true random

LFSR_16 LFSR_16_unit(
    .clk(clk), 
    .rst(reset), 
    .w_en(random_enable), 
    .w_in(random_16_seed), 
    .out(random_16)
    );
    
//-------------------------------------------------------------------------------------
// powerup logic
//-------------------------------------------------------------------------------------

localparam [1:0] NO_PU          = 3'b00,
                 RADIUS_PU      = 3'b01,
                 SPEED_PU       = 3'b10,
                 BOMB_PU        = 3'b11;
                 

wire random_enable;
reg [2:0] power_up_q;
reg [2:0] power_up_next_q;
reg [5:0] pu_x_reg, pu_y_reg, pu_x_next_q, pu_y_next_q;
wire [5:0] pu_x_next, pu_y_next;
reg [7:0] bomb_pu_q, radius_pu_q, speed_pu_q;
wire [15:0] pu_sprite_offset;
wire powerup_pickup;
wire bm_on;
reg picked_up_q;
wire picked_up_next;

assign pu_sprite_offset = (power_up_q == BOMB_PU) ? 0 :
                       (power_up_q == RADIUS_PU) ? 16 :
                       32;
                        
assign powerup_pickup = (powerup_on & bomberman_on);
                       

assign random_enable = bomb_exp_state_reg == post_exp && bomb_exp_state_next == no_bomb;

assign pu_x_next = A ? bomb_x_reg : pu_x_next_q;
assign pu_y_next = A ? bomb_y_reg : pu_y_next_q;

//assign bomb_on = (x_a[9:4] == bomb_x_reg & y_a[9:4] == bomb_y_reg & bomb_active);
assign powerup_on = (x_a[9:4] == pu_x_reg & y_a[9:4] == pu_y_reg) && power_up_q != NO_PU;
    
always @ (posedge clk, posedge reset) begin
    
    if(reset) begin
        radius_pu_q     <= 0;
        speed_pu_q      <= 0;
        pu_x_reg        <= 0;
        pu_y_reg        <= 0;
        power_up_q      <= 0;
        power_up_next_q <= 0;
        picked_up_q     <= 0;
    end
    else begin
        pu_x_next_q     <= pu_x_next;
        pu_y_next_q     <= pu_y_next;
        power_up_q      <= power_up_next_q;
        picked_up_q     <= picked_up_next;
        if(random_enable) begin// Identify the tansition from post bomb to no bomb
            pu_x_reg        <= pu_x_next_q;
            pu_y_reg        <= pu_y_next_q;
            case(random_16_seed[5:3])
                3'b010 : power_up_next_q    <= RADIUS_PU;
                3'b100 : power_up_next_q    <= SPEED_PU;
                default : power_up_next_q   <= NO_PU;
            endcase
        end else if(powerup_pickup) begin
            power_up_next_q <= NO_PU;
            case(power_up_q)
                BOMB_PU : radius_pu_q <= radius_pu_q + 1;
                SPEED_PU : speed_pu_q <= speed_pu_q + 1;
            endcase
        end
    
    end

end

assign speed_up = speed_pu_q;
powerup_sprites powerup_sprites_1(
    .a((x_a[3:0]) + {y_a[3:0] + pu_sprite_offset, 4'd0}),
    .spo(powerup_rgb)
);


reg [15:0] extra_radius_coutner_q;
reg [1:0] quadrent_counter;
reg [1:0] write_timer_buffer;
reg exp_pu_on;
// poer up explosion frames
always @ (posedge clk, posedge reset) begin
    // each incremetn of radius_pu_q is an extra ABM of blast radius
    if(reset) begin
        extra_radius_coutner_q  <= 0;
        quadrent_counter        <= 0;
        write_timer_buffer      <= 0;
        exp_pu_on               <= 0;
        
    end else begin
        case(quadrent_counter) 
            0 : begin // left
                if(write_timer_buffer < 3) begin 
                    write_timer_buffer <= write_timer_buffer + 1;
                    if(bomb_x_reg - extra_radius_coutner_q > 0) begin
                    
                    end
                end
                else begin
                    quadrent_counter <= quadrent_counter + 1;
                    write_timer_buffer <= 0;
                end
            end
            1 : begin // right 
                if(write_timer_buffer < 3) begin
                    write_timer_buffer <= write_timer_buffer + 1;
                end
                else begin
                    quadrent_counter <= quadrent_counter + 1;
                    write_timer_buffer <= 0;
                end
            end
            2 : begin // down
                if(write_timer_buffer < 3) begin
                    write_timer_buffer <= write_timer_buffer + 1;
                end
                else begin
                    quadrent_counter <= quadrent_counter + 1;
                    write_timer_buffer <= 0;
                end
            end
            3 : begin // up
                if(write_timer_buffer < 3) begin
                    write_timer_buffer <= write_timer_buffer + 1;
                end
                else begin
                    quadrent_counter <= 0; // back to 0th quadrent
                    write_timer_buffer <= 0;
                    if(extra_radius_coutner_q == radius_pu_q) begin
                        extra_radius_coutner_q <= 0;
                    end else begin
                        extra_radius_coutner_q <= extra_radius_coutner_q + 1;
                    end
                end
            end 
           
        endcase
    end 

end


endmodule
