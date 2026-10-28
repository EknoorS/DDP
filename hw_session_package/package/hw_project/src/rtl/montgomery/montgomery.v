`timescale 1ns / 1ps


// does adder_done automatiicaly go to zero after it gives 1 ? 

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
        .subtract (substraction),
        .in_a     (C),
        .in_b     (adderMuxOutput),
        .result   (adder_out  ),
        .done     (adder_done    ));

    reg adder_start;
    wire [379:0] adder_out;
    reg substraction;

    
// STATES 
localparam IDLE      = 3'd0,
           INIT      = 3'd1,
           ADD_B     = 3'd2,
           ADD_M     = 3'd3,
           SHIFT     = 3'd4,
           FINAL_SUB = 3'd5,
           DONE      = 3'd6;
localparam N         = 376; // This is the number of times we have to shift A_i 
           
    reg [8:0] counter;
    reg [2:0] state;
    reg [2:0] next_state;
    reg state_done;
    

    
    
    
    
    
    // state logics ; if some variable changes in here, run this code
    always@(*) begin
        // at each clk cycle we already determine the next state but the state will only change when and iff the current running state has been
        // marked as done in state_done
         begin
            case (state)
                IDLE: if (start) next_state <= INIT;
                INIT: next_state <= ADD_B;
                ADD_B: next_state <= ADD_M; 
                ADD_M: next_state <= SHIFT;
                SHIFT : next_state <= (counter < N) ? ADD_B : FINAL_SUB;
                FINAL_SUB : next_state <= DONE;
                DONE: next_state <= IDLE;
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
    
    
    // Set the Control Signals depending on what state we are landed
    always@(*) begin
        case(state)
            // INIT STATE: Only piece of code to run here; Setup all variables to start the FSM
            INIT : begin // Done 
                C <= 377'b0;
                counter <= 9'b0;
                substraction <= 1'b0;
                AShiftMuxSignal <= 1'b0;
                state_done <= 1'b1;
                end 
            ADD_B : begin // Done (state closing)
                adderMuxSignal <= 1;
                adderResultMux <= 0;
                adder_start <= 1;
            end 
            
            ADD_M: // Done (state closing)
                begin
                    if (C[0] == 1) begin
                    adderMuxSignal <= 0;
                    adderResultMux <= 1;
                    CShiftMuxSignal <= 1;
                    adder_start <= 1; // when done signal arrives, the flipflop updates and the state is marked done 
                    end 
                else begin
                    CShiftMuxSignal = 0;
                    adderResultMux = 1;
                    CClkSignal <= 1; // state marked done later in C FF 
                 end 
                end
                
            SHIFT: 
                begin
                AShiftMuxSignal <= 1'b1; // the first (INIT) time, its zero, after that, we change it and keep it on 1 
                AShiftClkSignal <= 1;
                counter <= counter + 1;
                end 
            FINAL_SUB: 
                begin
                    substraction = 1;
                    adderMuxSignal = 0;
                    adder_start = 1;
                end 
        endcase
      end 
  
    // reset these pulse signals the CLK cycle after they turned high
    // dont put in one single, otherwise race condition might arise due to
    // another variable change 
    always@(*) begin
        adder_start <= 0;           // 1
    end
    always@(*) begin
         AShiftClkSignal <= 0;      // 2
    end 
    
    always@(*) begin 
         CClkSignal <= 0;           // 3
    end
    
   // The clc cycle after the adder is done, we want to 
  // clock the FF to save the new calculated value
   always@(*) begin
    if ( adder_done == 1)
        CClkSignal <= 1; 
   end
       
        

    

  // 2. Use the Adder to implement the Montgomery multiplier in hardware.
  
  // BLOCK A
 
  // MUX
  wire [376:0] AShiftMuxOutput;
  reg AShiftMuxSignal;
  assign AShiftMuxOutput = (AShiftMuxSignal) ? a_reg >> 1 : in_a;
   
  // FF
  reg [376:0] a_reg;
  reg AShiftClkSignal;
  
  always@(posedge AShiftClkSignal) begin
    if (~resetn)
        a_reg <= 0;
     else
     a_reg <= AShiftMuxOutput; 
  end 
  
  
  // Block B
  
    
    reg adderMuxSignal;
    wire [376:0] BSelectorMuxOutput;
    wire [379: 0] adderMuxOutput; // APPEND 0's !!! 
    
    assign BSelectorMuxOutput = (a_reg[0]) ? in_b : 377'b0;
    assign adderMuxOutput = (adderMuxSignal) ? {3'b0, in_m} : {3'b0,BSelectorMuxOutput};
    
    // Block C
    reg adderResultMux;
    reg [376:0] C; // storing the sum C
    reg CShiftMuxSignal;
    wire [376:0] CShiftMuxOutput;
    assign CShiftMuxOutput = (CShiftMuxSignal) ? adder_out : C;
    
    wire [376:0] adderResultMuxOutput;
    assign adderResultMuxOutput = (adderResultMux) ?  CShiftMuxOutput >> 1 : adder_out;
    reg CClkSignal ;
    
    // C FlipFlop 
    always@(posedge CClkSignal, posedge resetn) begin
        if (~resetn)
            C <= 0;
        else 
        begin
            C = adderResultMuxOutput ;
            state_done <= 1; //  Always except the while loop, the state is done when the answer is stored in the FF 
        end 
    end 

  // 3. Use tb_montgomery.v to simulate your design.

    

endmodule