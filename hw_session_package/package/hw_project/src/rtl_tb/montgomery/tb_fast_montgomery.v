`timescale 1ns / 1ps
module tb_fast_montgomery;
    reg clk=0, resetn=0, start=0;
    reg [376:0] a, b, m;
    wire [376:0] result;
    wire done;
    always #5 clk = !clk;
    montgomery dut(.clk(clk),.resetn(resetn),.start(start),.in_a(a),
                   .in_b(b),.in_m(m),.result(result),.done(done));

    task check_product;
        input [376:0] av,bv,mv,expected;
        input integer expected_cycles;
        integer cycles;
        begin
            a=av; b=bv; m=mv; start=1;
            @(negedge clk); start=0;
            cycles=0;
            while (!done && cycles < 8000) begin
                @(negedge clk); cycles=cycles+1;
            end
            if (!done || result !== expected || cycles != expected_cycles)
                $fatal(1,"Wrong result or latency: cycles=%0d result=%h",cycles,result);
            $display("PASS: %0d FPGA clocks",cycles);
            @(negedge clk);
            if (done) $fatal(1,"Expected a one-cycle done pulse");
        end
    endtask
    initial begin
        repeat (3) @(negedge clk);
        resetn=1;
        // course_multiplication_2026_1
        check_product(
            377'h0b3eb7db58a59173ad3decf67899d507aa873f8519464a650dc13351fbd0bd15f6d04c91ae81f2358eb315cb94722f5,
            377'h00d0538111c4f2806116389d07bfbc7fb10acbba05fec63e0d9f6dc3b96323da462d16628dcfe5868cc4c7991bc8431,
            377'h12b020e99d2f12517bdd7ab745ab67c2c29c617b2959460b60fb0c2826d1e3ad9fc093313d1e814e3caba8d5bd24873,
            377'h0e1ed84ed5f280f30f75c3ecaa99ae9942618cdca1804c5556a7743d6e4656bfa95c4703b0f10711e1427ec7d93153c,
            116);
        // course_Gx_Gy
        check_product(
            377'h0767648b9422dde72206f349d4f065b8894aa243d552959b0f23fb9c732ef3fc6585971d2e97493734952a8decc5f31,
            377'h00a4629e5e925541c842f6662836666f31a521893f198babf955b78a541ff7376d4a72116b634a98e04f356c761573b,
            377'h1ae3a4617c510eac63b05c06ca1493b1a22d9f300f5138f1ef3622fba094800170b5d44300000008508c00000000001,
            377'h00dd56fc1827996ace232a7f006021f223dd2045bbbe33e7335d4786abad9e66fed770e8b69cdc070ffda4c532108c3,
            103);
        // group_order
        check_product(
            377'h000000000000000000000000000000012ab655e9a2ca55660b44d1e5c37b00159aa76fed00000010a11800000000000,
            377'h000000000000000000000000000000012ab655e9a2ca55660b44d1e5c37b00159aa76fed00000010a11800000000000,
            377'h000000000000000000000000000000012ab655e9a2ca55660b44d1e5c37b00159aa76fed00000010a11800000000001,
            377'h0000000000000000000000000000000016402d8c3bcc398b8f55d795aa5d50f545a1ece90bed864bd0663f2805818dc,
            103);
        $display("ALL FAST MULTIPLIER TESTS PASSED");
        $finish;
    end
endmodule
