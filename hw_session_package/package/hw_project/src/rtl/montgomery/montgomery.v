`timescale 1ns / 1ps

module montgomery(
  input           clk,
  input           resetn,
  input           start,
  input  [376:0] in_a,
  input  [376:0] in_b,
  input  [376:0] in_m,
  output [376:0] result,
  output          done
    );

    // Instantiating adder
    adder dut (
        .clk      (clk     ),
        .resetn   (resetn  ),
        .start    (adder_start   ),
        .subtract (1'b0),
        .in_a     (adder_in_a    ),
        .in_b     (C),
        .result   (adder_out  ),
        .done     (adder_done    ));
        
// STATES 
localparam IDLE      = 3'd0,
           INIT      = 3'd1,
           ADD_B     = 3'd2,
           ADD_M     = 3'd3,
           SHIFT     = 3'd4,
           FINAL_SUB = 3'd5,
           DONE      = 3'd6;

    reg [2:0] state;
    reg [2:0] next_state;
    reg state_done;
    
    reg [376:0] a_reg;
    reg [376:0] b_reg;
    
    wire [379:0] adder_in;
    
    // DATAPATH SIGNALS
    reg [376:0] C; // storing the sum C
    wire need_add_m = C[0] ^ (a_reg[0] & b_reg[0]); // wire telling us if the new C result will have a 0 or 1 as LSB 

    // state logics
    always@(posedge clk) begin
        // if reset signal is applied
        if (~resetn) begin  
            state = IDLE; 
            state_done = 0;
        end
        // at each clk cycle we already determine the next state but the state will only change when and iff the current running state has been
        // marked as done in state_done
        else begin
            case (state)
                IDLE: if (start) next_state <= INIT;
                INIT: next_state <= ADD_B;
                ADD_B: next_state = (need_add_m) ? ADD_M : SHIFT; 
                ADD_M: next_state <= SHIFT;
                SHIFT : next_state <= FINAL_SUB;
                default: next_state <= IDLE; 
                endcase
            end 
        end
    // change the state to the next_state if state is done 
    always@(posedge clk) begin
        if (~resetn) begin
            state <= IDLE;
            state_done = 0;
        end 
        else if (state_done) begin
            state <= next_state;
            state_done <= 0;
        end
    end


    reg adder_start;
    wire [379:0] adder_out;
    
    
    assign adder_in = (a_reg[0]) ? in_b : 380'b0; 
   
    // at every clc, we rightshift our a_reg then the assign will make sure the signal changes on the adder to add with the accumulated result
    always@(posedge clk) begin
        if (~resetn) 
            a_reg <= 380'b0;
        else if (start)
            a_reg <= {000, in_a}; // make it 380 bits 
        a_reg <= a_reg >> 1;
        adder_start <= 1'b1;
    end
    
    // reset the start signal of the adder at all clk fall
    always@(negedge clk) begin
        adder_start <= 1'b0;
    end 
  
  always@(posedge clk) begin
    
    
    
    
  end 

  // 2. Use the Adder to implement the Montgomery multiplier in hardware.
  
  
  
  
  
  
  // 3. Use tb_montgomery.v to simulate your design.

    

endmodule


