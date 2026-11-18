module ecdsa (
    input  wire          clk,
    input  wire          resetn,
    output wire   [ 3:0] leds,

    // input registers                     // output registers
    input  wire   [31:0] rin0,   // command/start          
    input  wire   [31:0] rin1,   // Address of A           
    input  wire   [31:0] rin2,   // Address of output         
    input  wire   [31:0] rin3,   // Address of B          
    input  wire   [31:0] rin4,   // Address of M           
    input  wire   [31:0] rin5,             
    input  wire   [31:0] rin6,             
    input  wire   [31:0] rin7,    
             
    output wire   [31:0] rout0,
    output wire   [31:0] rout1,
    output wire   [31:0] rout2,
    output wire   [31:0] rout3,
    output wire   [31:0] rout4,
    output wire   [31:0] rout5,
    output wire   [31:0] rout6,
    output wire   [31:0] rout7,
    
    // dma signals
    input  wire [1023:0] dma_rx_data,      output wire [1023:0] dma_tx_data,
    output wire [  31:0] dma_rx_address,   output wire [  31:0] dma_tx_address,
    output reg           dma_rx_start,     output reg           dma_tx_start,
    input  wire          dma_done,
    input  wire          dma_idle,
    input  wire          dma_error
  );


    reg [376:0] A;
    reg [376:0] B;
    reg [376:0] M;

    reg [1:0] rx_index; // determines which of A, B or M we are receiving 
                        // 0: A ; 1: B, 2: M 



  // In this example three input registers are used.
  // The first one is used for giving a command to FPGA.
  // The others are for setting DMA input and output data addresses.
  wire [31:0] command;
  assign command        = rin0; // use rin0 as command
  assign dma_rx_address = (rx_index == 0) ? rin1 :
                            (rx_index == 1) ? rin3 :
                                              rin4;
                                              
 // now we are going to put the DMA data in the registers A, B, and M 
 // by iterating over rin1, rin3, rin4 by counter rx_index                                              
                                              
  always @(posedge clk) begin
    if (!resetn) begin
        rx_index <= 0;
        A <= 0;
        B <= 0;
        M <= 0;
    end
    else begin
        if (state == STATE_IDLE)
            rx_index <= 0;

        if (state == STATE_RX_WAIT && dma_done) begin
            case (rx_index)
                0: A <= dma_rx_data[376:0];
                1: B <= dma_rx_data[376:0];
                2: M <= dma_rx_data[376:0];
            endcase

            if (rx_index < 2)
                rx_index <= rx_index + 1;
        end
    end
end                                            
    // instantiate montgomery and supporting vars                                           
    wire mont_start;
    wire mont_done;
    wire [376:0] mont_result;

    montgomery mont (
        .clk(clk),
        .resetn(resetn),
        .start(mont_start),
        .in_a(A),
        .in_b(B),
        .in_m(M),
        .result(mont_result),
        .done(mont_done)
    );                                             
                                                  
                                                  
                                              
                                              
                                              
                                              
                                              
                                              
                                              
  assign dma_tx_address = rin2; // use rin2 as output data address

  // Only one output register is used. It will the status of FPGA's execution.
  wire [31:0] status;
  assign rout0 = status; // use rout0 as status
  assign rout1 = 32'b0;  // not used
  assign rout2 = 32'b0;  // not used
  assign rout3 = 32'b0;  // not used
  assign rout4 = 32'b0;  // not used
  assign rout5 = 32'b0;  // not used
  assign rout6 = 32'b0;  // not used
  assign rout7 = 32'b0;  // not used


  // In this example we have only one computation command.
  wire isCmdComp = (command == 32'd1);
  wire isCmdIdle = (command == 32'd0);


  // Define state machine's states
  localparam
    STATE_IDLE     = 3'd0,
    STATE_RX       = 3'd1,
    STATE_RX_WAIT  = 3'd2,
    STATE_COMPUTE  = 3'd3,
    STATE_TX       = 3'd4,
    STATE_TX_WAIT  = 3'd5,
    STATE_DONE     = 3'd6,
    STATE_COMPUTE_WAIT = 3'd7;

  // The state machine
  reg [2:0] state = STATE_IDLE;
  reg [2:0] next_state;

  always@(*) begin
    // defaults
    next_state   <= STATE_IDLE;

    // state defined logic
    case (state)
      // Wait in IDLE state till a compute command
      STATE_IDLE: begin
        next_state <= (isCmdComp) ? STATE_RX : state;
      end

      // Wait, if dma is not idle. Otherwise, start dma operation and go to
      // next state to wait its completion.
      STATE_RX: begin
        next_state <= (~dma_idle) ? STATE_RX_WAIT : state;
      end

      // Wait the completion of dma.
    STATE_RX_WAIT: begin
        if (dma_done) begin
            if (rx_index == 2)
                next_state <= STATE_COMPUTE;
            else
                next_state <= STATE_RX;
        end
        else
            next_state <= state;
    end

          // A state for dummy computation for this example. Because this
          // computation takes only single cycle, go to TX state immediately
        STATE_COMPUTE: begin
            next_state <= STATE_COMPUTE_WAIT;
        end
        
        STATE_COMPUTE_WAIT: begin
            next_state <= mont_done ? STATE_TX : state;
        end

      // Wait, if dma is not idle. Otherwise, start dma operation and go to
      // next state to wait its completion.
      STATE_TX : begin
        next_state <= (~dma_idle) ? STATE_TX_WAIT : state;
      end

      // Wait the completion of dma.
      STATE_TX_WAIT : begin
        next_state <= (dma_done) ? STATE_DONE : state;
      end

      // The command register might still be set to compute state. Hence, if
      // we go back immediately to the IDLE state, another computation will
      // start. We might go into a deadlock. So stay in this state, till CPU
      // sets the command to idle. While FPGA is in this state, it will
      // indicate the state with the status register, so that the CPU will know
      // FPGA is done with computation and waiting for the idle command.
      STATE_DONE : begin
        next_state <= (isCmdIdle) ? STATE_IDLE : state;
      end

    endcase
  end

  always@(posedge clk) begin
    dma_rx_start <= 1'b0;
    dma_tx_start <= 1'b0;
    case (state)
      STATE_RX: dma_rx_start <= 1'b1;
      STATE_TX: dma_tx_start <= 1'b1;
    endcase
  end

  // Synchronous state transitions
  always@(posedge clk)
    state <= (~resetn) ? STATE_IDLE : next_state;

  assign mont_start = (state == STATE_COMPUTE);

  // Here is a register for the computation. Sample the dma data input in
  // STATE_RX_WAIT. Update the data with a dummy operation in STATE_COMP.
  // In this example, the dummy operation sets most-significant 32-bit to zeros.
  // Use this register also for the data output.
  
  // IMPORTANT!:
  // In your design, we only use data-transfers of up to 377 bits.(You may change this if you want.)
  // However, the underlying axi-stream that transfers the data uses a data size of 1024 bits.
  // We suggest the following approach to handle this mismatch: 
  // The testvector.py script generates all data and puts them in the LSBs. 
  // All higher bits are padded with zeros.
  // It is up to you to select these bits for correct usage.
  // Similarly, you are responsible for sending the results back to SW by aligning them as you expect.
  // In the waveform, you will still see the 1024 underlying bits from which the 377 MSB's are the ones that you are working with here!
  // IMPORTANT!
  
  reg [1023:0] r_data = 1024'h0;
  always@(posedge clk)
    case (state)
      STATE_RX_WAIT : r_data <= (dma_done) ? dma_rx_data : r_data;
      STATE_COMPUTE : r_data <= {32'hDEADBEEF, r_data[991:0]};
    endcase
  assign dma_tx_data = r_data;


  // Status signals to the CPU
  wire isStateIdle = (state == STATE_IDLE);
  wire isStateDone = (state == STATE_DONE);
  assign status = {29'b0, dma_error, isStateIdle, isStateDone};

endmodule
