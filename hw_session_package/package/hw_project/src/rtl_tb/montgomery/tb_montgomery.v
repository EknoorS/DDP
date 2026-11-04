`timescale 1ns / 1ps

`define RESET_TIME 25
`define CLK_PERIOD 10
`define CLK_HALF 5

module tb_montgomery();
    
    reg          clk;
    reg          resetn;
    reg          start;
    reg  [376:0] in_a;
    reg  [376:0] in_b;
    reg  [376:0] in_m;
    wire [376:0] result;
    wire         done;

    reg  [376:0] expected;
    reg          result_ok;
    
    //Instantiating montgomery module
    montgomery montgomery_instance( .clk    (clk    ),
                                    .resetn (resetn ),
                                    .start  (start  ),
                                    .in_a   (in_a   ),
                                    .in_b   (in_b   ),
                                    .in_m   (in_m   ),
                                    .result (result ),
                                    .done   (done   ));

    //Generate a clock
    initial begin
        clk = 0;
        forever #`CLK_HALF clk = ~clk;
    end
    
    //Reset
    initial begin
        resetn = 0;
        #`RESET_TIME resetn = 1;
    end
    
    // Test data
    initial begin

        #`RESET_TIME
        
            // You can generate your own with test vector generator python script
            in_a        <= 377'h04720ec535c2b907cf6ae8fe8641f3a8198151301468620cd17bc69812efa0841f731bd68fb250cb6bc3c0c7361cc60;
            in_b        <= 377'h16a80c5c63b1654b311f9a4f0855d7dc4e4e7a7b9cab28eb1b5d83f97227bb0f09ca9e07aac096a397b90ae2e733f51;
            in_m        <= 377'h1b74337881dd202c86f86acec471e0a24985ac7cd5dd52f929730e8cdd725df7d00d11d1be6e8479040dc68f9059177;
            expected <= 377'h11a07e0b1b13a39d571209998e9a97666a3add572ca862cd0d34f7b413afc3d279aa64781efe47a2db68455f212a786;
            
        start<=1;
        #`CLK_PERIOD;
        start<=0;
        
        wait (done==1);
        
        $display("result calculated=%x", result);
        $display("result expected  =%x", expected);
        $display("error            =%x", expected-result);
        result_ok = (expected==result);
        #`CLK_PERIOD;   
        
        $finish;
    end
           
endmodule