//******************************************************************************
// EE108B MIPS Verilog model
//
// mips_testbench.v
//******************************************************************************

`include "dvi_defines.v"
`include "mips_defines.v"

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
        $dumpfile("mipstest.vcd");
        $dumpvars(0, mips_testbench);
        rst = 0;
        #10;
        rst = 1;
        #10;
        rst = 0; play = 1;
        #10;
        play = 0;
        #20000;
        $stop;
    end

    always begin
        #20
        if (dut.cpu.en) begin
            if (dut.cpu.instr != `NOP) begin
                if (dut.cpu.d_stage.op == `SPECIAL)
                    $display("pc: %d, op: 0x%x, funct:0x%x, $rs: %d, $rt: %d, $rd, %d, shamt: %d",
                        dut.cpu.pc[10:0],
                        dut.cpu.d_stage.op,
                        dut.cpu.d_stage.funct,
                        dut.cpu.d_stage.rs_addr,
                        dut.cpu.d_stage.rt_addr,
                        dut.cpu.d_stage.rd_addr,
                        dut.cpu.d_stage.shamt
                    );
                else if (dut.cpu.d_stage.op == `J || dut.cpu.d_stage.op == `JAL)
                    $display("pc: %d, op: 0x%x, target: %d",
                        dut.cpu.pc[10:0],
                        dut.cpu.d_stage.op,
                        dut.cpu.d_stage.instr[25:0]
                    );
                else
                    $display("pc: %d, op: 0x%x, $rs: %d, $rt: %d, immediate: 0x%x",
                        dut.cpu.pc[10:0],
                        dut.cpu.d_stage.op,
                        dut.cpu.d_stage.rs_addr,
                        dut.cpu.d_stage.rt_addr,
                        dut.cpu.d_stage.immediate
                    );
                if (dut.cpu.m_stage.we)
                    $display("value 0x%x written to memory address: 0x%x",
                        dut.cpu.m_stage.data_in,
                        dut.cpu.m_stage.addr
                    );
                if (dut.cpu.w_stage.we)
                    $display("value 0x%x written to register: %d",
                        dut.cpu.w_stage.write_data,
                        dut.cpu.w_stage.write_addr
                    );
            end else
                $display("pc: %d, nop", dut.cpu.pc[10:0]);
        end
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
