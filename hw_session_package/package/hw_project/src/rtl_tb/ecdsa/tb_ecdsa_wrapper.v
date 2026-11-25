`timescale 1ns / 1ps

`define HUGE_WAIT    300
`define LONG_WAIT    100
`define RESET_TIME    25
`define CLK_PERIOD    10
`define CLK_HALF       5

module tb_ecdsa_wrapper();

  reg           clk;
  reg           resetn;
  wire [3:0]    leds;

  reg  [16:0]   mem_addr = 'b0;
  reg  [1023:0] mem_din  = 'b0;
  wire [1023:0] mem_dout;
  reg  [127:0]  mem_we   = 'b0;

  reg  [11:0] axil_araddr;
  wire        axil_arready;
  reg         axil_arvalid;
  reg  [11:0] axil_awaddr;
  wire        axil_awready;
  reg         axil_awvalid;
  reg         axil_bready;
  wire [1:0]  axil_bresp;
  wire        axil_bvalid;
  wire [31:0] axil_rdata;
  reg         axil_rready;
  wire [1:0]  axil_rresp;
  wire        axil_rvalid;
  reg  [31:0] axil_wdata;
  wire        axil_wready;
  reg  [3:0]  axil_wstrb;
  reg         axil_wvalid;

  tb_ecdsa_project_wrapper dut (
    .clk                 (clk),
    .leds                (leds),
    .resetn              (resetn),
    .s_axi_csrs_araddr   (axil_araddr),
    .s_axi_csrs_arready  (axil_arready),
    .s_axi_csrs_arvalid  (axil_arvalid),
    .s_axi_csrs_awaddr   (axil_awaddr),
    .s_axi_csrs_awready  (axil_awready),
    .s_axi_csrs_awvalid  (axil_awvalid),
    .s_axi_csrs_bready   (axil_bready),
    .s_axi_csrs_bresp    (axil_bresp),
    .s_axi_csrs_bvalid   (axil_bvalid),
    .s_axi_csrs_rdata    (axil_rdata),
    .s_axi_csrs_rready   (axil_rready),
    .s_axi_csrs_rresp    (axil_rresp),
    .s_axi_csrs_rvalid   (axil_rvalid),
    .s_axi_csrs_wdata    (axil_wdata),
    .s_axi_csrs_wready   (axil_wready),
    .s_axi_csrs_wstrb    (axil_wstrb),
    .s_axi_csrs_wvalid   (axil_wvalid),
    .mem_clk             (clk),
    .mem_addr            (mem_addr),
    .mem_din             (mem_din),
    .mem_dout            (mem_dout),
    .mem_en              (1'b1),
    .mem_rst             (~resetn),
    .mem_we              (mem_we)
  );

  // Clock
  initial begin
    clk = 0;
    forever #`CLK_HALF clk = ~clk;
  end

  // Initialize AXI signals
  initial begin
    axil_araddr  <= 'b0;
    axil_arvalid <= 'b0;
    axil_awaddr  <= 'b0;
    axil_awvalid <= 'b0;
    axil_bready  <= 'b0;
    axil_rready  <= 'b0;
    axil_wdata   <= 'b0;
    axil_wstrb   <= 'b0;
    axil_wvalid  <= 'b0;
  end

  // Reset
  initial begin
    resetn = 0;
    #`RESET_TIME;
    resetn = 1;
  end

  // Read from register
  task reg_read;
    input [11:0] reg_address;
    output [31:0] reg_data;
    begin
      axil_araddr  <= reg_address;
      axil_arvalid <= 1'b1;
      wait (axil_arready);
      #`CLK_PERIOD;
      axil_arvalid <= 1'b0;
      axil_rready  <= 1'b1;
      wait (axil_rvalid);
      reg_data <= axil_rdata;
      #`CLK_PERIOD;
      axil_rready <= 1'b0;
      // No display here, because we poll STATUS repeatedly.
      #`CLK_PERIOD;
      #`RESET_TIME;
    end
  endtask

  // Write to register
  task reg_write;
    input [11:0] reg_address;
    input [31:0] reg_data;
    begin
      axil_awaddr  <= reg_address;
      axil_awvalid <= 1'b1;
      axil_wdata  <= reg_data;
      axil_wstrb  <= 4'b1111;
      axil_wvalid <= 1'b1;
      wait (axil_awready);
      #`CLK_PERIOD;
      axil_awvalid <= 1'b0;
      wait (axil_wready);
      #`CLK_PERIOD;
      axil_wvalid <= 1'b0;
      axil_bready <= 1'b1;
      wait (axil_bvalid);
      #`CLK_PERIOD;
      axil_bready <= 1'b0;
      $display("[WRITE] reg[%x] <= %x", reg_address, reg_data);
      #`CLK_PERIOD;
      #`RESET_TIME;
    end
  endtask

  // Write 1024 bits to memory
  task mem_write;
    input [16:0] address;
    input [1023:0] data;
    begin
      mem_addr <= address;
      mem_din  <= data;
      mem_we   <= {128{1'b1}};
      #`CLK_PERIOD;
      mem_we   <= {128{1'b0}};
      $display("[WRITE] mem[%x]", address);
      #`CLK_PERIOD;
    end
  endtask

  // Read 1024 bits from memory and return the data
  task mem_read;
    input [16:0] address;
    output [1023:0] data;
    begin
      mem_addr <= address;
      #`CLK_PERIOD;
      #`CLK_PERIOD;
      #`CLK_PERIOD;
      data = mem_dout;
      $display("[READ] mem[%x]", address);
    end
  endtask

  // Byte addresses of 32-bit control registers
  localparam COMMAND  = 12'h000,
             RXADDR_A = 12'h004,
             TXADDR   = 12'h008,
             RXADDR_B = 12'h00c,
             RXADDR_M = 12'h010,
             STATUS   = 12'h000;

  // Four separate, 128-byte-aligned memory blocks
  localparam [16:0] MEM_A_ADDR = 17'h00000,
                    MEM_B_ADDR = 17'h00080,
                    MEM_M_ADDR = 17'h00100,
                    MEM_R_ADDR = 17'h00180;

  // Seed 2026, extracted from testvector.c
  localparam [376:0] A_VALUE = 377'h0767648b9422dde72206f349d4f065b8894aa243d552959b0f23fb9c732ef3fc6585971d2e97493734952a8decc5f31;
  localparam [376:0] B_VALUE = 377'h00a4629e5e925541c842f6662836666f31a521893f198babf955b78a541ff7376d4a72116b634a98e04f356c761573b;
  localparam [376:0] M_VALUE = 377'h1ae3a4617c510eac63b05c06ca1493b1a22d9f300f5138f1ef3622fba094800170b5d44300000008508c00000000001;

  // R_N = 2^377 mod M, for an independent second multiplication test
  localparam [376:0] R_VALUE = 377'h051c5b9e83aef1539c4fa3f935eb6c4e5dd260cff0aec70e10c9dd045f6b7ffe8f4a2bbcfffffff7af73fffffffffff;

  // Expected: (A * B * inverse(2^377)) mod M
  localparam [376:0] EXPECTED = 377'h00dd56fc1827996ace232a7f006021f223dd2045bbbe33e7335d4786abad9e66fed770e8b69cdc070ffda4c532108c3;

  reg [31:0] reg_status;
  reg [1023:0] result_data;
  integer attempts;

  initial begin
    #`LONG_WAIT;

    // Load A, B, M and clear output location
    mem_write(MEM_A_ADDR, {{647{1'b0}}, A_VALUE});
    mem_write(MEM_B_ADDR, {{647{1'b0}}, B_VALUE});
    mem_write(MEM_M_ADDR, {{647{1'b0}}, M_VALUE});
    mem_write(MEM_R_ADDR, 1024'b0);

    // Tell FPGA where to read inputs and write output
    reg_write(RXADDR_A, MEM_A_ADDR);
    reg_write(RXADDR_B, MEM_B_ADDR);
    reg_write(RXADDR_M, MEM_M_ADDR);
    reg_write(TXADDR, MEM_R_ADDR);

    $display("Starting Montgomery multiplication...");
    reg_write(COMMAND, 32'h00000001);

    // Poll done with a timeout
    attempts = 0;
    reg_read(STATUS, reg_status);
    while ((reg_status[0] !== 1'b1) && (attempts < 100000)) begin
      #`LONG_WAIT;
      reg_read(STATUS, reg_status);
      attempts = attempts + 1;
    end

    if (reg_status[0] !== 1'b1) begin
      $display("TEST FAILED: Timeout waiting for done. STATUS=%h", reg_status);
      $finish;
    end
    if (reg_status[2] === 1'b1) begin
      $display("TEST FAILED: DMA error. STATUS=%h", reg_status);
      $finish;
    end

    $display("FPGA finished. STATUS=%h", reg_status);
    reg_write(COMMAND, 32'h00000000);

    mem_read(MEM_R_ADDR, result_data);
    $display("Expected = %095h", EXPECTED);
    $display("Received = %095h", result_data[376:0]);

    if (result_data === {{647{1'b0}}, EXPECTED})
      $display("TEST 1 PASSED: Montgomery result is correct!");
    else begin
      $display("TEST 1 FAILED: Montgomery result does not match.");
      $finish;
    end

    // Wait for IDLE after clearing command, before another invocation.
    attempts = 0;
    reg_read(STATUS, reg_status);
    while ((reg_status[1] !== 1'b1) && (attempts < 1000)) begin
      reg_read(STATUS, reg_status);
      attempts = attempts + 1;
    end
    if (reg_status[1] !== 1'b1) begin
      $display("TEST 2 FAILED: FPGA did not return to IDLE.");
      $finish;
    end

    // Second test with a different B: MontMul(A, R_N, M) = A.
    mem_write(MEM_B_ADDR, {{647{1'b0}}, R_VALUE});
    mem_write(MEM_R_ADDR, 1024'b0);
    $display("Starting second Montgomery multiplication...");
    reg_write(COMMAND, 32'h00000001);

    attempts = 0;
    reg_read(STATUS, reg_status);
    while ((reg_status[0] !== 1'b1) && (attempts < 100000)) begin
      #`LONG_WAIT;
      reg_read(STATUS, reg_status);
      attempts = attempts + 1;
    end
    if ((reg_status[0] !== 1'b1) || (reg_status[2] === 1'b1)) begin
      $display("TEST 2 FAILED: timeout or DMA error. STATUS=%h", reg_status);
      $finish;
    end

    reg_write(COMMAND, 32'h00000000);
    mem_read(MEM_R_ADDR, result_data);
    $display("Test 2 expected = %095h", A_VALUE);
    $display("Test 2 received = %095h", result_data[376:0]);

    if (result_data === {{647{1'b0}}, A_VALUE})
      $display("TEST 2 PASSED: Back-to-back call works!");
    else
      $display("TEST 2 FAILED: Montgomery result does not match.");

    $finish;
  end

  // Global watchdog in case an AXI handshake gets stuck
  initial begin
    #30000000;
    $display("TEST FAILED: Global simulation timeout.");
    $finish;
  end

endmodule
