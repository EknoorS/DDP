`timescale 1ns / 1ps
// Radix 8192 Montgomery multiplication. Each lane holds the contribution
// of one 13-bit limb, including its local carry into the next limb.
module montgomery (
    input clk, resetn, start,
    input [376:0] in_a, in_b, in_m,
    output reg [376:0] result,
    output done
);
    localparam IDLE = 0, ADD_PRODUCT = 1, CORRECTION = 2, ADD_MODULUS = 3,
               NORMALIZE = 4, WAIT_NORMAL = 5, SUBTRACT = 6, WAIT_SUB = 7,
               COMPLETE = 8, BUILD_INVERSE = 9;
    localparam W = 13, LANES = 29;
    reg [3:0] state;
    reg [4:0] digit_index;
    reg [376:0] a_shift;
    reg [W-1:0] correction;
    reg [2*W:0] lane [0:LANES-1];
    wire reducing = state == ADD_MODULUS;
    wire [W-1:0] multiplier_digit = reducing ? correction : a_shift[W-1:0];

    // Divide the combined lanes by 8192 by moving each low part one
    // position down. The upper bits are already in the correct position.
    wire [376:0] low_parts, middle_parts, overflow_bits;
    genvar j;
    generate for (j=0; j<LANES; j=j+1) begin : digit_lane
        wire [W-1:0] next_low;
        if (j+1 < LANES)
            assign next_low = lane[j+1][W-1:0];
        else
            assign next_low = 0;

        wire [W+1:0] shifted_value = {1'b0, lane[j][2*W:W]} +
                                      {{2{1'b0}}, next_low};
        wire [W-1:0] operand = reducing ? in_m[j*W +: W] : in_b[j*W +: W];
        wire [2*W:0] addend = reducing ? lane[j] : {{(W-1){1'b0}}, shifted_value};
        // Time-share the multiplier for a_i * B_j and correction * M_j.
        (* use_dsp = "yes" *) wire [2*W-1:0] product = multiplier_digit * operand;
        wire [2*W:0] mac_result = {1'b0,product} + addend;

        always @(posedge clk) begin
            if (state == IDLE && start) lane[j] <= 0;
            else if (state == ADD_PRODUCT || reducing) lane[j] <= mac_result;
        end
        assign low_parts[j*W +: W] = next_low;
        assign middle_parts[j*W +: W] = lane[j][2*W-1:W];
        assign overflow_bits[j*W +: W] = {{(W-1){1'b0}},lane[j][2*W]};
    end endgenerate

    // For arbitrary odd M, form mu = -inverse(M) mod 8192 once per product.
    // Starting from 1, each chosen inverse bit makes the residual even.
    // The curve prime and group order both have low digit 1, hence mu = -1.
    reg [3:0] bit_index;
    reg [W-1:0] inverse_digit, residual;
    wire [W:0] even_residual = {1'b0,residual} +
                               (residual[0] ? {1'b0,in_m[W-1:0]} : 14'd0);
    wire simple_modulus = in_m[W-1:0] == 13'd1;
    wire [W-1:0] generic_digit = lane[0][W-1:0] * inverse_digit;

    // After the final digit, combine the three output vectors. XOR/majority
    // turn three words into two with no carry propagation across the lanes.
    wire [379:0] lo = {3'b0,low_parts};
    wire [379:0] mid = {3'b0,middle_parts};
    wire [379:0] hi = {3'b0,overflow_bits} << W;
    wire [379:0] binary_sum = lo ^ mid ^ hi;
    wire [379:0] binary_carry = ((lo & mid) | (lo & hi) | (mid & hi)) << 1;

    reg [379:0] total;
    wire [380:0] wide_out;
    wire wide_done;
    adder final_adder(.clk(clk), .resetn(resetn),
        .start(state == NORMALIZE || state == SUBTRACT), .subtract(state == SUBTRACT),
        .in_a(state == SUBTRACT ? total : binary_sum),
        .in_b(state == SUBTRACT ? {3'b0,in_m} : binary_carry),
        .result(wide_out), .done(wide_done));

    assign done = state == COMPLETE;
    // As in the original module, the caller holds B and M until done.
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            state <= IDLE;
            result <= 0;
        end else case (state)
            IDLE: if (start) begin
                a_shift <= in_a;
                digit_index <= 0;
                residual <= 1;
                bit_index <= 0;
                state <= simple_modulus ? ADD_PRODUCT : BUILD_INVERSE;
            end
            BUILD_INVERSE: begin
                inverse_digit <= {residual[0],inverse_digit[W-1:1]};
                residual <= even_residual[W:1];
                bit_index <= bit_index + 1'b1;
                if (bit_index == W-1) state <= ADD_PRODUCT;
            end
            ADD_PRODUCT: state <= CORRECTION;
            CORRECTION: begin
                correction <= simple_modulus ? -lane[0][W-1:0] : generic_digit;
                state <= ADD_MODULUS;
            end
            ADD_MODULUS: begin
                a_shift <= a_shift >> W;
                digit_index <= digit_index + 1'b1;
                state <= digit_index == LANES-1 ? NORMALIZE : ADD_PRODUCT;
            end
            NORMALIZE: state <= WAIT_NORMAL;
            WAIT_NORMAL: if (wide_done) begin
                total <= wide_out[379:0];
                state <= SUBTRACT;
            end
            SUBTRACT: state <= WAIT_SUB;
            WAIT_SUB: if (wide_done) begin
                result <= wide_out[380] ? total[376:0] : wide_out[376:0];
                state <= COMPLETE;
            end
            COMPLETE: state <= IDLE;
            default: state <= IDLE;
        endcase
    end
endmodule
