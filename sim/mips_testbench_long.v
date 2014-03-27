//******************************************************************************
// EE108B MIPS Verilog model
//
// mips_testbench.v
//******************************************************************************

`include "dvi_defines.v"

module mips_testbench();

    wire select;
    wire chip_hsync, chip_vsync, chip_data_enable, chip_reset;
    wire [11:0] chip_data;
    wire scl, sda;
    wire [3:0] leds;
    wire xclk, xclk_n;
    
    reg clk, rst, play;
    
    initial clk = 0;
    
    initial begin
        rst = 0;
        #40;
        rst = 1;
        #40;
        rst = 0;
        #40;
        play = 1;
        #40
        play = 0;
        #40000000; $stop;
    end
    
    always
        #5 clk = ~clk;

    mips_top dut (
        .clk(clk),
        .chip_hsync(chip_hsync),
        .chip_vsync(chip_vsync),
        .chip_data(chip_data),
        .chip_reset(chip_reset),
        .chip_data_enable(chip_data_enable),
        .xclk(xclk),
        .xclk_n(xclk_n),
        .sw(8'b0),
        .left_btn(play),
        .center_btn(1'b0),
        .right_btn(1'b0),
        .top_btn(rst),
        .bottom_btn(1'b0),
        .leds(leds),
        .scl(scl),
        .sda(sda)
    );

endmodule

