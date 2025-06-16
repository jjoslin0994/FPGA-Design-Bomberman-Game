module enemy_module
(
    input wire clk, reset, display_on,
    input wire [9:0] x, y,                   // current pixel location on screen
    input wire [9:0] x_b, y_b,               // bomberman coordinates
    input wire bomb_on, exp_on, post_exp_active,      // signal asserted when explosion on screen and active (bomb_exp_state_reg == post_exp)
    output wire [11:0] rgb_out,              // enemy rgb out
    output wire enemy_on,                    // signal asserted when x/y pixel coordinates are within enemy tile on screen
    output reg enemy_hit,                     // output asserted when in "exp_enemy" state
    output wire led
);

reg [5:0] count ;
reg [27:0] hit_timer_q;
wire [27:0] hit_timer;

localparam BM_HB_OFFSET_9 = 8;             // offset from top of sprite down to top of 16x16 hit box  
localparam BM_HB_HALF     = 8;             // half length of bomberman hitbox

localparam X_WALL_L = 48;                  // end of left wall x coordinate
localparam X_WALL_R = 576;                 // begin of right wall x coordinate
localparam Y_WALL_U_2 = 32;                  // bottom of top wall y coordinate
localparam Y_WALL_D = 448;                 // top of bottom wall y coordinate
localparam HIT_MAX = 150000000;


assign led = led_q;
assign enemy_hit_next = (exp_on && enemy_on) ? 1 : (hit_timer_q == HIT_MAX) ? 0 : enemy_hit;

always @ (posedge clk, posedge reset) begin
    if(reset)
        hit_timer_q <= 0;
    else 
        hit_timer_q <= hit_timer;
end

assign hit_timer = (enemy_hit && hit_timer_q < HIT_MAX) ? hit_timer_q + 1 : 0;


// symbolic state declarations
localparam [2:0] idle            = 3'b000,  // wait for motion timer reg to hit max val
                 move_btwn_tiles = 3'b001,  // move enemy in current dir 15 pixels
                 get_rand_dir    = 3'b010,  // get random_dir from LFSR and set r_addr to block module block_map
                 check_dir       = 3'b011,  // check if new dir is blocked by wall or pillar
                 exp_enemy       = 3'b100;  // state for when explosion tile intersects with enemy tile
                 
localparam ARENA_LEFT_EDGE = 48;
localparam ARENA_TOP_EDGE = 32;
localparam ARENA_RIGHT_EDGE = 575;
localparam ARENA_BOTTOM_EDGE = 463;

localparam CD_U = 2'b00;
localparam CD_D = 2'b11;
localparam CD_L = 2'b01;                      // current direction register vals
localparam CD_R = 2'b10;

localparam UP = 2'b00;
localparam DOWN = 2'b11;
localparam LEFT = 2'b01;
localparam RIGHT = 2'b10;

   


localparam Y_WALL_U = 31;                   // bottom of top wall y coordinate

localparam ENEMY_H_9 = 8;
localparam ENEMY_WH = 16;                   // enemy width
localparam ENEMY_H = 24;                    // enemy height

localparam LOW_RIGHT_X = 576 - ENEMY_WH + 1;
localparam LOW_RIGHT_Y = 448 - ENEMY_H_9; 

// y indexing constants into enemy sprite ROM. 3 frames for UP, RIGHT, DOWN, one frame for when enemy is hit.
localparam U_1 = 0;
localparam U_2 = 24;
localparam U_3 = 48;
localparam R_1 = 72;
localparam R_2 = 96;
localparam R_3 = 120;
localparam D_1 = 144;
localparam D_2 = 168;
localparam D_3 = 192;
localparam exp = 216;

localparam TIMER_MAX = 4000000;                          // max value for motion_timer_reg

localparam ENEMY_X_INIT = X_WALL_L + 10*ENEMY_WH;        // enemy initial value
localparam ENEMY_Y_INIT = Y_WALL_U + 10*ENEMY_H + 8;        


reg [7:0] rom_offset_reg, rom_offset_next;               // register to hold y index offset into bomberman sprite ROM
reg [2:0] e_state_reg, e_state_next;                     // register for enemy FSM states      
reg [21:0] motion_timer_reg; 
wire [21:0] motion_timer_next;          // delay timer reg, next_state for setting speed of enemy
reg [21:0] motion_timer_max_reg; 
wire [21:0] motion_timer_max_next;  // max value of motion timer reg, gets shorter as game progresses
reg [5:0] move_cnt_reg; 
wire [5:0] move_cnt_next;                   // register to count from 0 to 15, number of pixel steps between tiles
reg [9:0] x_e_reg, y_e_reg;
wire [9:0] x_e_next, y_e_next;          // enemy x/y location reg, next_state in abm
reg [1:0] e_cd_reg, e_cd_next;   
wire motion_timer_tick;                        

wire [9:0] x_e_a = (x_e_reg - X_WALL_L);                 // enemy coordinates in arena coordinate frame
wire [9:0] y_e_a = (y_e_reg - Y_WALL_U);
wire [5:0] x_e_abm = x_e_a[9:4];                         // enemy location in ABM coordinates
wire [5:0] y_e_abm = y_e_a[9:4]; 

wire [15:0] random_16;
wire [15:0] random_16_seed;




localparam MOVE = 0;
localparam NEW_DIRECTION = 1;

       
assign random_16_seed = (count * (x_b+y_b)) & 16'hFFFF; // base random seed off player locaton to guarantee a true random

// infer LFSR module, used to get pseudorandom direction for enemy and pseudorandom chance of getting new direction
LFSR_16 LFSR_16_unit(
    .clk(clk), 
    .rst(reset), 
    .w_en(random_enable), 
    .w_in(random_16_seed), 
    .out(random_16)
    );

 

always @ (posedge clk, posedge reset) begin
    if(reset) begin
        count <= 1;
        motion_timer_reg <= 0;
    end else begin
        count <= (count < 63) ? count + 1 : 1;
        case(e_state_reg) 
          MOVE :  motion_timer_reg <= motion_timer_next;
          
          default : motion_timer_reg <= 0;
          
          endcase
    end
end

assign motion_timer_next = ((motion_timer_reg < motion_timer_max_reg) ? motion_timer_reg + 1 : 0); // increment 
assign motion_timer_tick = motion_timer_reg == motion_timer_max_reg; // tick at rollover

assign motion_timer_max_next = (!enemy_hit && enemy_hit_next) ? motion_timer_max_reg - 100000 : motion_timer_max_reg;

assign move_cnt_next = at_edge || !(move_cnt_reg < 32) ? 0 : motion_timer_tick & ~enemy_hit  ? move_cnt_reg + 1 : move_cnt_reg;

//assign led = random_16 == 0;
reg led_q;


// increment the x position based on dirrection
assign x_e_next = (enemy_hit) ? x_e_reg : ((e_cd_reg == LEFT) && (e_state_reg == MOVE) && motion_timer_tick) ? x_e_reg - 1 : 
                  ((e_cd_reg == RIGHT) && (e_state_reg == MOVE) && motion_timer_tick) ? x_e_reg + 1 : 
                  x_e_reg;

// increment the y position based on direction
assign y_e_next = (enemy_hit) ? y_e_reg : ((e_cd_reg == UP) && (e_state_reg == MOVE) && motion_timer_tick) ? y_e_reg - 1 : 
                  ((e_cd_reg == DOWN) && (e_state_reg == MOVE) && motion_timer_tick) ? y_e_reg + 1 : 
                  y_e_reg;


wire at_edge;
wire [9:0] enemy_hitBox_left, enemy_hitBox_right, enemy_hitBox_top, enemy_hitBox_bottom;

// detect arena edge
assign at_edge = (e_cd_reg == UP && enemy_hitBox_top == 0) ? 1 : //
                (e_cd_reg == DOWN && enemy_hitBox_bottom == 432) ? 1 :
                (e_cd_reg == LEFT && enemy_hitBox_left == 0) ? 1 :
                (e_cd_reg == RIGHT && enemy_hitBox_right == 527) ? 1 : 
                0;



reg random_enable;



always @ (posedge clk, posedge reset) begin
    if (reset)begin
        enemy_hit <= 0;
        random_enable <= 0;
        led_q <= 0;
        e_state_reg          <= MOVE;
        x_e_reg              <= ENEMY_X_INIT;          
        y_e_reg              <= ENEMY_Y_INIT;
        e_cd_reg             <= UP;
        move_cnt_reg         <= 0; 
        motion_timer_max_reg <=  TIMER_MAX;
    end else begin
        enemy_hit            <= enemy_hit_next;
        e_state_reg          <= e_state_next;
        x_e_reg              <= x_e_next;
        y_e_reg              <= y_e_next;
        e_cd_reg             <= e_cd_next;
		motion_timer_max_reg <= motion_timer_max_next;
        move_cnt_reg         <= move_cnt_next;
    

        case (e_state_reg) 
            MOVE : begin
                if (move_cnt_reg == 32 || at_edge) begin     
                    random_enable <= 1;
                    e_state_next = NEW_DIRECTION;
                end
            end
            
            NEW_DIRECTION : begin
                //led_q <= 1;
                random_enable <= 0;
                case (random_16[4:2])
                    3'b000 : begin
                        e_cd_next <= random_16[1:0];
                    end
                    default : begin 
                        if(at_edge) begin
                            e_cd_next <= ~e_cd_reg;
                        end else begin
                            e_cd_next <= e_cd_reg;
                            end
                        end
                endcase
                e_state_next = MOVE;
            end
            
        endcase
    end
end






// define hitbox of enemy character
assign enemy_hitBox_left = x_e_reg - ARENA_LEFT_EDGE;
assign enemy_hitBox_right = x_e_reg - ARENA_LEFT_EDGE + 15;
assign enemy_hitBox_top = y_e_reg - ARENA_TOP_EDGE + 8;
assign enemy_hitBox_bottom = y_e_reg - ARENA_TOP_EDGE + 23;

                        
// assign output telling top_module when to display bomberman's sprite on screen
assign enemy_on = (x >= x_e_reg) & (x <= x_e_reg + ENEMY_WH - 1) & (y >= y_e_reg) & (y <= y_e_reg + ENEMY_H - 1);

// infer register for index offset into sprite ROM using current direction and frame timer register value
always @(posedge clk, posedge reset)
      if(reset)
         rom_offset_reg <= 0;
      else 
         rom_offset_reg <= rom_offset_next;

// next-state logic for rom offset reg
always @(posedge clk)
      begin
      if(enemy_hit) begin     // explosion hit enemy
         led_q <= ~led_q;
         rom_offset_next = exp;
      end else if(move_cnt_reg[3:2] == 1)  // move_cnt_reg = 4-7
         begin
         if(e_cd_reg == CD_U)          
            rom_offset_next = U_2;
         else if(e_cd_reg == CD_D)
            rom_offset_next = D_2;
         else 
            rom_offset_next = R_2;
         end
      else if(move_cnt_reg[3:2] == 3)   // move_cnt_reg = 12-15
         begin
         if(e_cd_reg == CD_U)
            rom_offset_next = U_3;
         else if(e_cd_reg == CD_D)
            rom_offset_next = D_3;
         else 
            rom_offset_next = R_3;
         end
      else                              // move_cnt_reg = 0-3, 8-11
         begin
         if(e_cd_reg == CD_U) 
            rom_offset_next = U_1;
         else if(e_cd_reg == CD_D)
            rom_offset_next = D_1;
         else 
            rom_offset_next = R_1;
         end
      end

// block ram address, indexing mirrors right sprites when moving left
wire [11:0] br_addr = (e_cd_reg == CD_L) ? 15 - (x - x_e_reg) + ((y-y_e_reg+rom_offset_reg) << 4) 
                                         :      (x - x_e_reg) + ((y-y_e_reg+rom_offset_reg) << 4);

// instantiate bomberman sprite ROM
enemy_sprite_br enemy_s_unit(
    .clka(clk), 
    .ena(1'b1),
    .addra(br_addr),
    .douta(rgb_out));

endmodule
