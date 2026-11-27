module ecdsa #(
    parameter VARIABLE_MODULUS = 1,
    parameter POINT_ONLY = 0  // area experiment: expose only command 2
) (
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
    localparam [376:0] Q = 377'h1ae3a4617c510eac63b05c06ca1493b1a22d9f300f5138f1ef3622fba094800170b5d44300000008508c00000000001;
    localparam IDLE=0, READ_REQ=1, READ_WAIT=2, COMPUTE=4,
               WRITE_REQ=5, WRITE_WAIT=6, COMPLETE=7;
    reg [2:0] state, index;
    reg point_requested;
    wire point_mode = POINT_ONLY ? 1'b1 : point_requested;
    reg [376:0] modulus;
    reg [31:0] a_base, b_base, m_base, out_base;
    wire [31:0] offset = {23'b0,index[1:0],7'b0};
    assign dma_rx_address = point_mode ? ((index[2] ? b_base : a_base) + offset)
                            : (index == 0 ? a_base : index == 1 ? b_base : m_base);
    assign dma_tx_address = out_base + offset;
    always @* begin
        dma_rx_start = resetn && state == READ_REQ && dma_idle;
        dma_tx_start = resetn && state == WRITE_REQ && dma_idle;
    end
    wire [376:0] value;
    wire finished;
    // The last DMA acknowledgement also starts the engine. FETCH occurs next cycle.
    wire [2:0] last_read = point_mode ? 3'd7 : (VARIABLE_MODULUS ? 3'd2 : 3'd1);
    wire start_engine = state == READ_WAIT && dma_done && index == last_read;
    ec_add #(.POINT_MODULUS(Q)) engine(.clk(clk), .resetn(resetn), .start(start_engine),
        .point_mode(point_mode), .modulus(VARIABLE_MODULUS ? modulus : Q),
        .load(state == READ_WAIT && dma_done && (point_mode || index < 2)),
        .load_slot(index), .load_value(dma_rx_data[376:0]),
        .result_slot(index[1:0]), .result(value), .done(finished));
    assign dma_tx_data = {647'b0,value};
    assign rout0 = {29'b0,dma_error,(state == IDLE),(state == COMPLETE)};
    assign rout1 = 32'h45434131; // ASCII ECA1, checked by the Vitis application
    assign rout2 = POINT_ONLY ? 32'h53484d50 :
                   (VARIABLE_MODULUS ? 32'h53484d31 : 32'h53484d30); // SHMP / SHM1 / SHM0
    assign {rout3,rout4,rout5,rout6,rout7} = 160'b0;
    assign leds = {point_mode,state};
    always @(posedge clk) begin
        if (!resetn) begin
            state <= IDLE;
            point_requested <= 0;
            index <= 0;
        end else case (state)
            IDLE: if (rin0 == 2 || (!POINT_ONLY && rin0 == 1)) begin
                point_requested <= rin0 == 2;
                a_base <= rin1;
                out_base <= rin2;
                b_base <= rin3;
                m_base <= VARIABLE_MODULUS ? rin4 : 0;
                modulus <= Q;
                index <= 0;
                state <= READ_REQ;
            end
            READ_REQ: if (dma_idle) state <= READ_WAIT;
            READ_WAIT: if (dma_done) begin
                if (VARIABLE_MODULUS && !point_mode && index == 2) modulus <= dma_rx_data[376:0];
                if (index == last_read) begin
                    index <= 0;
                    state <= COMPUTE;
                end else begin
                    index <= index + 1'b1;
                    state <= READ_REQ;
                end
            end
            COMPUTE: if (finished) state <= WRITE_REQ;
            WRITE_REQ: if (dma_idle) state <= WRITE_WAIT;
            WRITE_WAIT: if (dma_done) begin
                if (!point_mode || index == 3) state <= COMPLETE;
                else begin
                    index <= index + 1'b1;
                    state <= WRITE_REQ;
                end
            end
            COMPLETE: if (rin0 == 0) state <= IDLE;
            default: state <= IDLE;
        endcase
    end
endmodule
