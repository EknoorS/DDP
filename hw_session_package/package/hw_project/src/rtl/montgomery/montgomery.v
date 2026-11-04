
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

    // adder
    reg adder_start;
    wire adder_done;
    wire [380:0] adder_out;
    reg substraction;

    reg [379:0] C;
    wire [379:0] adderMuxOutput;

    adder dut (
        .clk      (clk),
        .resetn   (resetn),
        .start    (adder_start),
        .subtract (substraction),
        .in_a     (C),
        .in_b     (adderMuxOutput),
        .result   (adder_out),
        .done     (adder_done)
    );

    // Group A
    wire [376:0] AShiftMuxOutput;
    reg AShiftMuxSignal;
    reg [376:0] a_reg;

    // Group B
    reg adderMuxSignal;
    wire [376:0] BSelectorMuxOutput;

    // Group C
    reg adderResultMux;
    reg CShiftMuxSignal;
    wire [380:0] CShiftMuxOutput;
    wire [380:0] adderResultMuxOutput;

    // STATES
    localparam IDLE      = 3'd0,
               INIT      = 3'd1,
               ADD_B     = 3'd2,
               ADD_M     = 3'd3,
               SHIFT     = 3'd4,
               FINAL_SUB = 3'd5,
               DONE      = 3'd6;

    localparam N = 376;

    reg [8:0] counter;
    reg [2:0] state;
    reg [2:0] next_state;
    reg [2:0] prev_state;
    reg state_done;


    // Next state logic
    always @(*) begin
        case (state)
            IDLE:      next_state = start ? INIT : IDLE;
            INIT:      next_state = ADD_B;
            ADD_B:     next_state = ADD_M;
            ADD_M:     next_state = SHIFT;
            SHIFT:     next_state = (counter < N) ? ADD_B : FINAL_SUB;
            FINAL_SUB: next_state = DONE;
            DONE:      next_state = IDLE;
            default:   next_state = IDLE;
        endcase
    end


    // Change state when current state is finished
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            state <= IDLE;
            prev_state <= IDLE;
        end
        else begin
            prev_state <= state;

            if (state_done)
                state <= next_state;
        end
    end


    // Set control signals depending on state
    always @(*) begin
        // Default values
        state_done = 0;
        adder_start = 0;
        substraction = 0;
        AShiftMuxSignal = 0;
        adderMuxSignal = 0;
        adderResultMux = 0;
        CShiftMuxSignal = 0;

        case (state)

            IDLE: begin
                if (start)
                    state_done = 1;
            end

            INIT: begin
                state_done = 1;
            end

            ADD_B: begin
                adderMuxSignal = 1;
                adderResultMux = 0;
                adder_start = (state != prev_state);

                if (adder_done)
                    state_done = 1;
            end

            ADD_M: begin
                adderMuxSignal = 0;
                adderResultMux = 1;

                if (C[0]) begin
                    CShiftMuxSignal = 1;
                    adder_start = (state != prev_state);

                    if (adder_done)
                        state_done = 1;
                end
                else begin
                    CShiftMuxSignal = 0;
                    state_done = 1;
                end
            end

            SHIFT: begin
                AShiftMuxSignal = 1;
                state_done = 1;
            end

            FINAL_SUB: begin
                adderMuxSignal = 0;
                substraction = 1;
                adderResultMux = 0;
                adder_start = (state != prev_state);

                if (adder_done)
                    state_done = 1;
            end

            DONE: begin
                state_done = 1;
            end

        endcase
    end


    // DONE STATE LOGIC
    assign done = (state == DONE);
    assign result = C[376:0];


    // BLOCK A

    // MUX
    assign AShiftMuxOutput = AShiftMuxSignal ? a_reg >> 1 : in_a;

    // FF and counter
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            a_reg <= 0;
            counter <= 0;
        end
        else if (state == INIT) begin
            a_reg <= AShiftMuxOutput;
            counter <= 0;
        end
        else if (state == SHIFT) begin
            a_reg <= AShiftMuxOutput;
            counter <= counter + 1;
        end
    end


    // BLOCK B

    assign BSelectorMuxOutput = a_reg[0] ? in_b : 377'b0;

    assign adderMuxOutput = adderMuxSignal ?
                            {3'b0, BSelectorMuxOutput} :
                            {3'b0, in_m};


    // BLOCK C

    assign CShiftMuxOutput = CShiftMuxSignal ? adder_out : {1'b0, C};

    assign adderResultMuxOutput = adderResultMux ?
                                  CShiftMuxOutput >> 1 : adder_out;

    // C FlipFlop
    always @(posedge clk or negedge resetn) begin
        if (!resetn)
            C <= 0;

        else if (state == INIT)
            C <= 0;

        else if (state == ADD_B && adder_done)
            C <= adderResultMuxOutput[379:0];

        else if (state == ADD_M && (!C[0] || adder_done))
            C <= adderResultMuxOutput[379:0];

        else if (state == FINAL_SUB && adder_done) begin
            if (!adder_out[380])
                C <= adderResultMuxOutput[379:0];
        end
    end

endmodule
