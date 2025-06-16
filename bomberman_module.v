module bomberman_module
(
   input wire clk, reset,
   input wire [9:0] x, y,       // current pixel location on screen
   input wire L, R, U, D,       // controller input
   input wire [1:0] cd,         // bomberman current direction
   input wire bm_blocked,       // asserted when bomberman is blocked by a block in his current location and direction
   input wire gameover,         // asserted when game lives == 0
   input wire [15:0] speed_up,
   output wire bomberman_on,    // signal asserted when pixel location is within sprite location on screen
   output wire bm_hb_on,        // output asserted when pixel location is within sprite hitbox location on screen
   output wire [9:0] x_b, y_b,  // top left corner of sprite arena coordinates
   output wire [11:0] rgb_out,   // output color data
   output wire led
   
);



//******************************************************************** CONSTANTS ********************************************************************

localparam TIMER_MAX = 1200000;                 // max value of motion_timer_reg

localparam CD_U = 2'b00;                        // current direction register vals
localparam CD_R = 2'b01;
localparam CD_D = 2'b10;
localparam CD_L = 2'b11;

localparam FRAME_CNT_1 = 12500000;              // sprite frame animation count ranges 
localparam FRAME_CNT_2 = 2*FRAME_CNT_1;
localparam FRAME_CNT_3 = 3*FRAME_CNT_1;
localparam FRAME_CNT_4 = 4*FRAME_CNT_1;
localparam FRAME_REG_MAX = 50000000;

localparam BM_HB_OFFSET_9 = 8;                  // offset from top of sprite down to top of 16x16 hit box              
localparam BM_WIDTH       = 16;                 // sprite width
localparam BM_HEIGHT      = 24;                 // sprite height

localparam UP_LEFT_X   = 48;                    // constraints of Bomberman sprite location (upper left corner) within arena.
localparam UP_LEFT_Y   = 32;
localparam LOW_RIGHT_X = 576 - BM_WIDTH + 1;
localparam LOW_RIGHT_Y = 448 - BM_HB_OFFSET_9;           


// y indexing constants into bomberman sprite ROM. 3 frames for UP, RIGHT, DOWN, LEFT.
localparam U_1 = 0;
localparam U_2 = 24;
localparam U_3 = 48;
localparam R_1 = 72;
localparam R_2 = 96;
localparam R_3 = 120;
localparam D_1 = 144;
localparam D_2 = 168;
localparam D_3 = 192;
//End of declaring indexing constants for bomberman sprite ROM

//The indexing constant into death animation sprite ROM should take place here.

//End of declaring indexing constants for death animation sprite ROM 

//******************************************************************** WIRES & REGS ******************************************************************

// delay timer reg, next_state, and tick for setting speed of bomberman motion
reg  [20:0] motion_timer_reg;
wire [20:0] motion_timer_next;
reg [20:0] motion_timer_max_q;
wire motion_timer_tick;
wire [20:0] motion_timer_max_next;
reg [15:0] local_speed_up;

// bomberman x/y location reg, next_state
reg  [9:0] x_b_reg,  y_b_reg;
wire [9:0] x_b_next, y_b_next;

// register to count time between walking frames
reg  [32:0] frame_timer_reg;
wire [32:0] frame_timer_next;

// register to hold y index offset into bomberman sprite ROM
reg  [8:0] rom_offset_reg;
reg  [8:0] rom_offset_next;


//************************************************************** MOTION TIMER REGISTER ****************************************************************

// infer register for motion_timer
always @(posedge clk, posedge reset)
      if(reset) begin
         motion_timer_max_q     <= TIMER_MAX;
         motion_timer_reg       <= 0;
         local_speed_up         <= 0;
      end
      else begin
         motion_timer_reg <= motion_timer_next;
         motion_timer_max_q <= motion_timer_max_next;
         local_speed_up <= speed_up;
      end

// next state logic for motion timer: increment when bomberman to move and timer less than max, else reset.
assign motion_timer_next =  ((L | R | U | D) & (motion_timer_reg < motion_timer_max_q))? motion_timer_reg + 1 : 0;

assign motion_timer_max_next = (local_speed_up < speed_up) ? motion_timer_max_q - 20000 : motion_timer_max_q;

// tick every time timer rolls over, used to signal when to actually move bomberman.
assign motion_timer_tick = motion_timer_reg == motion_timer_max_q;
                    
//************************************************************** PILLAR COLLISION SIGNALS *************************************************************

// pillar collision signals, asserted when sprite hit box will collide with 
// left, right, top, bottom side of pillar if sprite hitbox where to 
// move in that direction.
wire p_c_up, p_c_down, p_c_left, p_c_right;

// determine p_c_down & p_c_up signals:

wire [9:0] x_b_hit_l, x_b_hit_r, y_b_bottom, y_b_top;
assign x_b_hit_l  = x_b_reg - UP_LEFT_X;                        // x coordinate of left  edge of hitbox
assign x_b_hit_r  = x_b_reg - UP_LEFT_X + BM_WIDTH - 1;         // x coordinate of right edge of hitbox
assign y_b_bottom = y_b_reg - UP_LEFT_Y + BM_HEIGHT + 1;        // y coordiante of bottom of hitbox if sprite were going to move down (y + 1)
assign y_b_top    = y_b_reg - UP_LEFT_Y + BM_HB_OFFSET_9 - 1;   // y coordinate of top of hitbox if sprite were going to move up (y - 1)


// sprite will collide if going down if the bottom of the hitbox would be within a pillar (5th bit == 1), 
// and either the left or right edges of the hit box are within the x coordinates of a pillar (5th bit == 1)
assign p_c_down = ((y_b_bottom[4] == 1) & (x_b_hit_l[4] == 1 | x_b_hit_r[4] == 1));   

// sprite will collide if going up if the top of the hitbox would be within a pillar (5th bit == 1), 
// and either the left or right edges of the hit box are within the x coordinates of a pillar (5th bit == 1)
assign p_c_up   = ((   y_b_top[4] == 1) & (x_b_hit_l[4] == 1 | x_b_hit_r[4] == 1));

// determine p_c_left & p_c_right signals:

wire [9:0] y_b_hit_t, y_b_hit_b, x_b_left, x_b_right;
assign y_b_hit_t = y_b_reg - UP_LEFT_Y + BM_HB_OFFSET_9; // y coordinate of the top edge of the hitbox
assign y_b_hit_b = y_b_reg - UP_LEFT_Y + BM_HEIGHT -1;   // y coordiate of the bottom edge of the hitbox
assign x_b_left  = x_b_reg - UP_LEFT_X - 1;              // x coordinate of the left edge of the hitbox if the sprite were going to move left (x - 1)
assign x_b_right = x_b_reg - UP_LEFT_X + BM_WIDTH + 1;   // x coordinate of the right edge of the hitbox if the sprite were going to move right (x + 1)


// sprite will collide if going left if the left edge of the hitbox would be within a pillar (5th bit == 1), 
// and either the top or bottom edges of the hit box are within the x coordinates of a pillar (5th bit == 1)
assign p_c_left  = ( (x_b_left[4] == 1) & (y_b_hit_t[4] == 1 | y_b_hit_b[4] == 1)) ? 1 : 0;

// sprite will collide if going right if the right edge of the hitbox would be within a pillar (5th bit == 1), 
// and either the top or bottom edges of the hit box are within the x coordinates of a pillar (5th bit == 1)
assign p_c_right = ((x_b_right[4] == 1) & (y_b_hit_t[4] == 1 | y_b_hit_b[4] == 1)) ? 1 : 0;

//******************************************************  SPRITE X/Y COORDINATE REGISTERS ********************************************************

// infer registers for bomberman sprite x/y location
always @(posedge clk, posedge reset)
    if (reset)
        begin
        x_b_reg     <= UP_LEFT_X + 16;  // initial location                
        y_b_reg     <= UP_LEFT_Y - BM_HB_OFFSET_9;  
        end
    else
        begin
        if(local_speed_up < speed_up)begin
            led_q <= ~led_q;
        end
        x_b_reg     <= x_b_next;
        y_b_reg     <= y_b_next;
        end

// offset values used to avoid corner case where bomberman walks into block when going around a pillar
// to witness corner cases, use original values in two assignments below.
wire [9:0] x_b_hit_l_m1 = x_b_hit_l - 1;   
wire [9:0] x_b_hit_r_p1 = x_b_hit_r + 1;
wire [9:0] y_b_hit_t_m1 = y_b_hit_t - 1;
wire [9:0] y_b_hit_b_p1 = y_b_hit_b + 1;

// next state logic for bomberman location
assign x_b_next = (!gameover & !bm_blocked & motion_timer_tick) ?
                  (cd == CD_R & ~p_c_right & x_b < LOW_RIGHT_X) |                  // can move right into a clear row
                  (cd == CD_U & p_c_up     & x_b_hit_l_m1[4] == 1) |               // moving up into top right of pillar, go right and around
                  (cd == CD_D & p_c_down   & x_b_hit_l_m1[4] == 1)? x_b_reg + 1:   // moving down into bottom right of pillar, go right and around
                          
                  (cd == CD_L & ~p_c_left  & x_b > UP_LEFT_X) |                    // can move left into a clear row
                  (cd == CD_U & p_c_up     & x_b_hit_r_p1[4] == 1) |               // moving up into top left of pillar, go left and around
                  (cd == CD_D & p_c_down   & x_b_hit_r_p1[4] == 1)                 // moving up into botom left of pillar, go left and around
                  ? x_b_reg - 1 : x_b_reg : x_b_reg;
                  
assign y_b_next = (!gameover & !bm_blocked & motion_timer_tick) ?
                  (cd == CD_D & ~p_c_down  & y_b < LOW_RIGHT_Y) |                  // can move down a clear column
                  (cd == CD_R & p_c_right  & y_b_hit_t_m1[4] == 1) |               // moving right into bottom side of pillar, go down and around 
                  (cd == CD_L & p_c_left   & y_b_hit_t_m1[4]  == 1)? y_b_reg + 1:  // moving left into bottom side of pillar, go down and around
                  
                  (cd == CD_U & ~p_c_up    & y_b > (UP_LEFT_Y - BM_HB_OFFSET_9)) | // can move up a clear column 
                  (cd == CD_R & p_c_right  & y_b_hit_b_p1[4] == 1) |               // moving right into top side of pillar, go up and around
                  (cd == CD_L & p_c_left   & y_b_hit_b_p1[4] == 1)                 // moving left into top side of pillar, go up and around
                  ? y_b_reg - 1 : y_b_reg : y_b_reg;

      
//************************************************************ ANIMATION FRAME TIMER **************************************************************

wire movement;
reg [31:0] frame_max_q;
wire [31:0] frame_max_next;
wire frame_timer_tick;
assign movement = ((U + D + L + R) == 1) ? 1 : 0;

assign frame_timer_next = (!movement) ? frame_timer_q : (frame_timer_q < frame_max_q) ? frame_timer_q + 1 : 0;
assign frame_timer_tick = frame_timer_q == frame_max_q;
assign frame_max_next = (local_speed_up < speed_up) ? frame_max_q - 20000 : frame_max_q;

assign led = led_q;
reg led_q;

localparam [1:0] first_frame     = 2'b00,
                 second_frame    = 2'b01,
                 third_frame     = 2'b10,
                 fourth_frame    = 2'b11;
                 

                 
reg [1:0] cur_frame;
reg [31:0] frame_timer_q;

always @ (posedge clk, posedge reset) begin
    if(reset) begin
        frame_timer_q <= 0;
        cur_frame <= first_frame;
        frame_max_q <= 12500000;
    end else begin
        frame_timer_q <= frame_timer_next;
        frame_max_q <= frame_max_next;
        if(frame_timer_tick) begin
            case ({cur_frame} ) 
                {first_frame} : begin
                    //led_q <= ~led_q;
                    cur_frame <= second_frame;
                end
                {second_frame} : begin
                    cur_frame <= third_frame;
                end
               {third_frame} : begin
                    cur_frame <= fourth_frame;
               end
               {fourth_frame}: begin
                    cur_frame <= first_frame;
               end
               
               default : cur_frame <= cur_frame;
              
                
            endcase
        end
    end

end


always @ (posedge clk) begin
    if(!movement) begin
        case(cd)
            CD_U : rom_offset_reg <= U_1;
            CD_D : rom_offset_reg <= D_1;
            CD_L : rom_offset_reg <= R_1;
            CD_R : rom_offset_reg <= R_1;
        endcase
    end
    else begin
        case (cur_frame)
            first_frame : begin
                case (cd) 
                    CD_U : rom_offset_reg <= U_1;
                    CD_D : rom_offset_reg <= D_1;
                    CD_L : rom_offset_reg <= R_1;
                    CD_R : rom_offset_reg <= R_1;
                    default : rom_offset_reg <= U_1;
                endcase        
            end
            second_frame : begin
                case (cd) 
                    CD_U : rom_offset_reg <= U_2;
                    CD_D : rom_offset_reg <= D_2;
                    CD_L : rom_offset_reg <= R_2;
                    CD_R : rom_offset_reg <= R_2;
                    default : rom_offset_reg <= U_1;
                endcase   
            end
            third_frame : begin
                case (cd) 
                    CD_U : rom_offset_reg <= U_1;
                    CD_D : rom_offset_reg <= D_1;
                    CD_L : rom_offset_reg <= R_1;
                    CD_R : rom_offset_reg <= R_1;
                    default : rom_offset_reg <= U_1;
                endcase           
            end
            fourth_frame : begin
                case (cd) 
                    CD_U : rom_offset_reg <= U_3;
                    CD_D : rom_offset_reg <= D_3;
                    CD_L : rom_offset_reg <= R_3;
                    CD_R : rom_offset_reg <= R_3;
                    default : rom_offset_reg <= U_1;
                endcase           
            end
            default : ;
            
        endcase
    end
end

//********************************************************** INSTANTIATE ROM & ASSIGN OUTPUTS *****************************************************
    

// index into the rom using x/y, sprite location, and rom_offset, mirroring x for current direction being left
wire [11:0] br_addr = (cd == CD_L) ? 15 - (x - x_b_reg) + {(y-y_b_reg+rom_offset_reg), 4'd0} 
                                   :      (x - x_b_reg) + {(y-y_b_reg+rom_offset_reg), 4'd0};



wire [11:0] game_over_rgb; 
assign rgb_out = (gameover) ? game_over_rgb : sprite_rgb;

wire [11:0] sprite_rgb;
// instantiate bomberman sprite ROM
bm_sprite_br bm_s_unit(
    .clka(clk), 
    .ena(1'b1), 
    .addra(br_addr), 
    .douta(sprite_rgb)
    );

localparam DEATH_TIMER_MAX = 100000000;
localparam [2:0] death_frame_1 = 0,
                 death_frame_2 = 1,
                 death_frame_3 = 2,
                 death_frame_4 = 3,
                 death_frame_5 = 4;
reg [31:0] death_timer_q;
reg [2:0] death_frame_q;
wire [31:0] death_timer_next;
wire [31:0] death_timer_tick;
reg [8:0] death_rom_offset;

assign death_timer_next = (gameover & death_timer_q < DEATH_TIMER_MAX) ? death_timer_q + 1 : 0;
assign death_timer_tick = death_timer_q == DEATH_TIMER_MAX;

always @ (posedge clk, posedge reset) begin
    if(reset) begin
        death_timer_q <= 0;
        death_rom_offset <= 0;
        death_frame_q <= 0;
    end
    else begin
        death_timer_q <= death_timer_next;
        if(death_timer_tick)begin
            case(death_frame_q)
                death_frame_1 : begin
                    death_frame_q <= death_frame_q + 1;
                    death_rom_offset <= 0;
                end
                death_frame_2 : begin
                    death_frame_q <= death_frame_q + 1;
                    death_rom_offset <= 24;
                    
                end
                death_frame_3 : begin
                    death_frame_q <= death_frame_q + 1;
                    death_rom_offset <= 48;                    
                end
                death_frame_4 : begin
                    death_frame_q <= death_frame_q + 1;
                    death_rom_offset <= 72;                    
                end
                death_frame_5 : begin
                    death_rom_offset <= 96;                    
                end
            endcase
        end
    end
end

wire [11:0] br_addr_death = (x - x_b_reg) + {(y-y_b_reg+death_rom_offset), 4'd0};

 bm_death_sprite bm_death_s_unit (
    .clka(clk),
    .ena(1'b1),
    .addra(br_addr_death),
    .douta(game_over_rgb)
 );

// assign output for bomberman sprite location        
assign x_b = x_b_reg;
assign y_b = y_b_reg;
                  
// assign output telling top_module when to display bomberman's sprite on screen
assign bomberman_on = (x >= x_b_reg) & (x <= x_b_reg + BM_WIDTH - 1) & (y >= y_b_reg) & (y <= y_b_reg + BM_HEIGHT - 1);

// assign output, asserted when x/y vga pixel coordinates are within bomberman hitbox - used in game_lives
assign bm_hb_on = (x >= x_b_reg) & (x <= x_b_reg + BM_WIDTH - 1) & 
                  (y >= y_b_reg + BM_HB_OFFSET_9) & (y <= y_b_reg + BM_HEIGHT - 1);

endmodule
