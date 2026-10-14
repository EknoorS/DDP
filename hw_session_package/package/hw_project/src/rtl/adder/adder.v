`timescale 1ns / 1ps

module adder(
  input  wire          clk,
  input  wire          resetn,
  input  wire          start,
  input  wire          subtract,
  input  wire [379:0]  in_a,
  input  wire [379:0]  in_b,
  output reg  [380:0]  result,
  output reg           done    
  );


  localparam ADDER_WIDTH = 64;
  localparam NUM_CHUNKS   = 6;
  localparam PAD_WIDTH    = 384;

  reg [PAD_WIDTH-1:0] a_reg;
  reg [PAD_WIDTH-1:0] b_reg;
  reg [PAD_WIDTH-1:0] result_reg;
  reg carry_reg;
  reg [2:0] count;
  reg busy;
  reg subtract_reg;

  wire [ADDER_WIDTH-1:0] b_operand;
  wire [ADDER_WIDTH:0] chunk_sum;


  assign b_operand = subtract_reg ? ~b_reg[ADDER_WIDTH-1:0]:  b_reg[ADDER_WIDTH-1:0];

  assign chunk_sum = {1'b0, a_reg[ADDER_WIDTH-1:0]}+ {1'b0, b_operand} + carry_reg;
  

  always @(posedge clk) begin
    if (!resetn) begin

      a_reg        <= 384'b0;
      b_reg        <= 384'b0;
      result_reg   <= 384'b0;

      carry_reg    <= 1'b0;
      count        <= 3'b0;

      busy         <= 1'b0;
      subtract_reg <= 1'b0;

      result       <= 381'b0;// i want it immediatly
      done         <= 1'b0;

    end
    else if (start && !busy) begin

      a_reg <= {4'b0000, in_a};
      b_reg <= {4'b0000, in_b};

      result_reg <= 384'b0;
      subtract_reg <= subtract;

      carry_reg <= subtract;

      count <= 3'b0;

      busy <= 1'b1;
      done <= 1'b0;

    end
    else if (busy) begin
      result_reg <= {
        chunk_sum[ADDER_WIDTH-1:0],
        result_reg[PAD_WIDTH-1:ADDER_WIDTH]
      };

      carry_reg <= chunk_sum[ADDER_WIDTH];

      a_reg <= a_reg >> ADDER_WIDTH;
      b_reg <= b_reg >> ADDER_WIDTH;

      if (count == NUM_CHUNKS-1) begin

        result <= {
          chunk_sum[60:0],
          result_reg[PAD_WIDTH-1:ADDER_WIDTH]
        };

        busy <= 1'b0;
        done <= 1'b1;

      end
      else begin

        count <= count + 1'b1;

        done <= 1'b0;

      end

    end

    else begin

      done <= 1'b0;

    end

  end

endmodule
