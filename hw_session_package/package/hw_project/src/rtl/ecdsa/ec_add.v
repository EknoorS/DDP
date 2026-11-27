`timescale 1ns / 1ps
// Eight input coordinates occupy slots 0..7. Results replace slots 0..3
// only after their original values have been consumed.
// Zero preserves the original direct-module interface. The course wrapper
// supplies q because ADD/SUB are executed only in the curve-point program.
module ec_add #(parameter [376:0] POINT_MODULUS = 377'd0) (
    input wire clk, resetn, start, point_mode,
    input wire load, input wire [2:0] load_slot,
    input wire [376:0] load_value, modulus,
    input wire [1:0] result_slot,
    output wire [376:0] result,
    output wire done
);
    localparam [376:0] KR = 377'h0c5e2f3c8bd4a6f76eaac1eeb5440814482f8d517faf2532624e377854a1bbf5646e689d0c1f552322c8dfd08894e0e;
    localparam MUL=2'd0, ADD=2'd1, SUB=2'd2;
    localparam IDLE=0, FETCH=1, ISSUE=2, WAIT_RESULT=3, COMPLETE=4;
    reg [2:0] state;
    reg [4:0] step;
    reg [376:0] slots [0:15];
    reg [376:0] left_operand, right_operand;
    reg [1:0] op;
    reg [3:0] left_slot, right_slot, destination;
    assign result = slots[{2'b00,result_slot}];
    assign done = state == COMPLETE;

    // Instruction fields: operation, first source, second source, destination.
    // 0..3 = X1,Y1,Z1,T1; 4..7 = X2,Y2,Z2,T2.
    // 8..11 become A,B,C,D; 12..15 become E,F,G,H.
    always @* begin
        {op,left_slot,right_slot,destination} = {MUL,4'd0,4'd1,4'd0};
        if (point_mode) begin
            case (step)
                 0: {op,left_slot,right_slot,destination} = {SUB,4'd1,4'd0,4'd12}; // Y1-X1
                 1: {op,left_slot,right_slot,destination} = {SUB,4'd5,4'd4,4'd13}; // Y2-X2
                 2: {op,left_slot,right_slot,destination} = {MUL,4'd12,4'd13,4'd8}; // A
                 3: {op,left_slot,right_slot,destination} = {ADD,4'd1,4'd0,4'd12}; // Y1+X1
                 4: {op,left_slot,right_slot,destination} = {ADD,4'd5,4'd4,4'd13}; // Y2+X2
                 5: {op,left_slot,right_slot,destination} = {MUL,4'd12,4'd13,4'd9}; // B
                 6: {op,left_slot,right_slot,destination} = {MUL,4'd3,4'd7,4'd10}; // T1*T2
                 7: {op,left_slot,right_slot,destination} = {MUL,4'd10,4'd0,4'd10}; // C (second operand is kR)
                 8: {op,left_slot,right_slot,destination} = {MUL,4'd2,4'd6,4'd11}; // Z1*Z2
                 9: {op,left_slot,right_slot,destination} = {ADD,4'd11,4'd11,4'd11}; // D
                10: {op,left_slot,right_slot,destination} = {SUB,4'd9,4'd8,4'd12}; // E
                11: {op,left_slot,right_slot,destination} = {SUB,4'd11,4'd10,4'd13}; // F
                12: {op,left_slot,right_slot,destination} = {ADD,4'd11,4'd10,4'd14}; // G
                13: {op,left_slot,right_slot,destination} = {ADD,4'd9,4'd8,4'd15}; // H
                14: {op,left_slot,right_slot,destination} = {MUL,4'd12,4'd13,4'd0}; // X
                15: {op,left_slot,right_slot,destination} = {MUL,4'd14,4'd15,4'd1}; // Y
                16: {op,left_slot,right_slot,destination} = {MUL,4'd13,4'd14,4'd2}; // Z
                17: {op,left_slot,right_slot,destination} = {MUL,4'd12,4'd15,4'd3}; // T
                default: ;
            endcase
        end
    end

    wire mult_done, add_done;
    wire [376:0] product, sum;
    montgomery mult(.clk(clk), .resetn(resetn), .start(state == ISSUE && op == MUL),
        .in_a(left_operand), .in_b(right_operand), .in_m(modulus),
        .result(product), .done(mult_done));
    modadder addsub(.clk(clk), .resetn(resetn), .start(state == ISSUE && op != MUL),
        .subtract(op == SUB), .in_a(left_operand), .in_b(right_operand),
        .in_m(POINT_MODULUS == 0 ? modulus : POINT_MODULUS),
        .result(sum), .done(add_done));

    wire ready = op == MUL ? mult_done : add_done;
    always @(posedge clk) begin
        if (load)
            slots[{1'b0,load_slot}] <= load_value;
        else if (state == WAIT_RESULT && ready)
            slots[destination] <= op == MUL ? product : sum;
        if (!resetn) begin
            state <= IDLE;
            step <= 0;
        end else case (state)
            IDLE: if (start) begin
                step <= 0;
                state <= FETCH;
            end
            FETCH: begin
                left_operand <= slots[left_slot];
                right_operand <= point_mode && step == 7 ? KR : slots[right_slot];
                state <= ISSUE;
            end
            ISSUE: state <= WAIT_RESULT;
            WAIT_RESULT: if (ready) begin
                if (!point_mode || step == 17)
                    state <= COMPLETE;
                else begin
                    step <= step + 1'b1;
                    state <= FETCH;
                end
            end
            default: state <= IDLE;
        endcase
    end
endmodule
