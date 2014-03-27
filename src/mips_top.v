//=============================================================================
// EE108B Lab 3
//
// Top level module. Integrates the various system components.
//=============================================================================

module mips_top (
    /* clock in */
    input clk,

    /* dvi signals out */
    output chip_hsync,
    output chip_vsync,
    output [11:0] chip_data,
    output chip_reset,
    output chip_data_enable,
    output xclk,
    output xclk_n,

    /* tactile inputs -> switches */
    input [7:0] sw,
    input left_btn,
    input center_btn,
    input right_btn,
    input top_btn,
    input bottom_btn,

    /* leds out */
    output [3:0] leds,

    /* I2C */
    inout scl,
    inout sda
);
    
    //=============================================================================
    // Input controls
    //=============================================================================
    wire rst = ~|sw & top_btn;
    wire run_toggle, run, step, trap;
    wire debug_select = center_btn;

    wire [13:0] display_data;
    wire display_we;

    button_press_unit run_button_unit (.clk(clk), .rst(rst), .in(~|sw & left_btn), .out(run_toggle));
    button_press_unit step_button_unit (.clk(clk), .rst(rst), .in(~|sw & right_btn), .out(step));
    button_press_unit trap_button_unit (.clk(clk), .rst(rst), .in(~|sw & bottom_btn), .out(trap));

    dffr run_dff (.r(rst), .clk(clk), .d(run_toggle ^ run), .q(run));
    
    wire clk_half;
    dffar clk_div (.r(~rst), .clk(clk), .d(~clk_half), .q(clk_half));

    wire mipsclk = clk_half;
    wire memclk = ~mipsclk;

    mips_cpu cpu (
        .clk            (mipsclk),
        .memclk         (memclk),
        .rst            (~rst),
        .en             (run | step),
        .trap           (trap),
        .controller_data(|sw ? {28'b0, left_btn, right_btn, top_btn, bottom_btn} : 32'b0),
        .display_data   (display_data),
        .display_we     (display_we)
    ); 
 
    
    //==========================================================================
    // Display management -> do not touch!
    //==========================================================================
    /* blinking leds to show life */
    wire [26:0] led_counter;

    dff #(.WIDTH (27)) led_div (
        .clk (clk),
        .d (led_counter + 27'd1),
        .q (led_counter)
    );
    assign leds = led_counter[26:23];

    // These signals come from and go to the modules for generating the 
    // VGA timing (sync) signals
    wire [10:0] x;  // [0..1279]
    wire [9:0] y;   // [0..1023]     

    // Create composite RGB signal
    wire [5:0] vga_rgb;
         
    // VGA Colors
    wire [7:0] r, g, b, v_r, v_g, v_b, r_cb, g_cb, b_cb;
 
    // DVI test pattern selection
    assign {r,g,b} = debug_select ? {r_cb,g_cb,b_cb} : {v_r,v_g,v_b};
 
    assign v_r = {4{vga_rgb[5:4]}};
    assign v_g = {4{vga_rgb[3:2]}};
    assign v_b = {4{vga_rgb[1:0]}};
 
    dvi_controller_top ctrl(
        .clk    (clk),
        .en     (1'b1),
        .rst    (rst),
        .r      (r),
        .g      (g),
        .b      (b),

        .chip_data_enable (chip_data_enable),
        .chip_hsync       (chip_hsync),
        .chip_vsync       (chip_vsync),
        .chip_reset       (chip_reset),
        .chip_data        (chip_data),
        .xclk             (xclk),
        .xclk_n           (xclk_n),
        .x                (x),
        .y                (y)
    );
 
    // Display Driver
    mips_display mips_disp (
        .clk            (mipsclk),
        .XPos           (x[10:5]),
        .YPos           (y[9:5]),
        .display_data   (display_data),
        .we             (display_we),
        .valid          (1'b1),

        .vga_rgb        (vga_rgb)
    );
 
    // I2C controller to configure dvi interface
    i2c_emulator i2c_controller(
        .clk (clk),
        .rst (rst),

        .scl (scl),
        .sda (sda)
    );

    // Color bars for testing the display
    color_bars tp (
        .x (x),
        .y (y),

        .r (r_cb[7:0]),
        .g (g_cb[7:0]),
        .b (b_cb[7:0])
    );
    
endmodule
