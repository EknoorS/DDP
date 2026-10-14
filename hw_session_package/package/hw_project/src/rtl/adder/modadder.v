`timescale 1ns / 1ps

module modadder(
input wire [376:0] in_a,
input wire [376:0] in_b,
input wire [376:0] in_m,
input wire subtract,
input wire start,
input wire clk,
input wire resetn,
output reg [376:0] result,
output reg done
);

localparam IDLE = 2'd0;
localparam WAIT_A = 2'd1;
localparam WAIT_B = 2'd2;
localparam CHECK = 2'd3;

reg [1:0] state;
reg [376:0] in_m_reg;
reg subtract_reg;
reg modOperationNeeded;

wire adderA_start;
wire adderA_subtract;
wire [379:0] adderA_a;
wire [379:0] adderA_b;
wire [380:0] adderA_result;
wire adderA_done;

wire adderB_start;
wire adderB_subtract;
wire [379:0] adderB_a;
wire [379:0] adderB_b;
wire [380:0] adderB_result;
wire adderB_done;

assign adderA_a = {3'b000, in_a};
assign adderA_b = {3'b000, in_b};
assign adderA_start = (state == IDLE) && start;
assign adderA_subtract = subtract;

adder adderA (
.clk(clk),
.resetn(resetn),
.start(adderA_start),
.subtract(adderA_subtract),
.in_a(adderA_a),
.in_b(adderA_b),
.result(adderA_result),
.done(adderA_done)
);

assign adderB_a = adderA_result[379:0];
assign adderB_b = {3'b000, in_m_reg};
assign adderB_subtract = ~subtract_reg;
assign adderB_start = (state == CHECK) && modOperationNeeded;

adder adderB (
.clk(clk),
.resetn(resetn),
.start(adderB_start),
.subtract(adderB_subtract),
.in_a(adderB_a),
.in_b(adderB_b),
.result(adderB_result),
.done(adderB_done)
);

always @(posedge clk) begin
    if (!resetn) begin
        state <= IDLE;
        in_m_reg <= 377'd0;
        subtract_reg <= 1'b0;
        modOperationNeeded <= 1'b0;
        result <= 377'd0;
        done <= 1'b0;
    end
    else begin
        done <= 1'b0;

        case (state)
            IDLE: begin
                if (start) begin
                    in_m_reg <= in_m;
                    subtract_reg <= subtract;
                    state <= WAIT_A;
                end
            end

            WAIT_A: begin
                if (adderA_done) begin
                    modOperationNeeded <= subtract_reg ?
                        adderA_result[380] :
                        (adderA_result >= {4'b0000, in_m_reg});

                    state <= CHECK;
                end
            end

            CHECK: begin
                if (modOperationNeeded) begin
                    state <= WAIT_B;
                end
                else begin
                    result <= adderA_result[376:0];
                    done <= 1'b1;
                    state <= IDLE;
                end
            end

            WAIT_B: begin
                if (adderB_done) begin
                    result <= adderB_result[376:0];
                    done <= 1'b1;
                    state <= IDLE;
                end
            end

            default: state <= IDLE;
        endcase
    end
end

endmodule