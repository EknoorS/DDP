`timescale 1ns / 1ps
module montgomery (
    input clk, resetn, start,
    input [376:0] in_a, in_b, in_m,
    output [376:0] result,
    output done
);
    localparam IDLE = 3'd0, ADD_B = 3'd1, ADD_M = 3'd2,
               FINAL_SUB = 3'd3, DONE = 3'd4;
    reg [2:0] state;
    reg [8:0] counter;
    reg [376:0] a_reg;
    reg [379:0] C;
    reg issued;
    wire adder_done;
    wire [380:0] adder_out;
    wire use_adder = (state == ADD_B && a_reg[0]) ||
                     (state == ADD_M && C[0]) || state == FINAL_SUB;
    wire adder_start = use_adder && !issued;
    wire [379:0] adder_b = state == ADD_B ? {3'b0, in_b} : {3'b0, in_m};

    // Keep B and M stable until done, as in the course interface.
    adder dut (.clk(clk), .resetn(resetn), .start(adder_start),
               .subtract(state == FINAL_SUB), .in_a(C), .in_b(adder_b),
               .result(adder_out), .done(adder_done));
    assign done = state == DONE;
    assign result = C[376:0];

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            state <= IDLE;
            C <= 0;
            counter <= 0;
            a_reg <= 0;
            issued <= 0;
        end else begin
            if (adder_start) issued <= 1;
            else if (adder_done) issued <= 0;
            case (state)
                IDLE: if (start) begin
                    C <= 0;
                    a_reg <= in_a;
                    counter <= 0;
                    state <= ADD_B;
                end
                ADD_B: if (!a_reg[0] || adder_done) begin
                    if (a_reg[0]) C <= adder_out[379:0];
                    state <= ADD_M;
                end
                ADD_M: if (!C[0] || adder_done) begin
                    // Commit one bit only after its optional addition finishes.
                    if (C[0]) C <= adder_out[380:1];
                    else C <= C >> 1;
                    a_reg <= a_reg >> 1;
                    counter <= counter + 1'b1;
                    state <= counter == 9'd376 ? FINAL_SUB : ADD_B;
                end
                FINAL_SUB: if (adder_done) begin
                    if (!adder_out[380]) C <= adder_out[379:0];
                    state <= DONE;
                end
                DONE: state <= IDLE;
                default: state <= IDLE;
            endcase
        end
    end
endmodule
