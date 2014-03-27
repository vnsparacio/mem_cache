//=============================================================================
// VGA display driver for MIPS
//
// Uses TCGROM to display colors based on the current screen location
//
// Updated: 2012/01/24
//=============================================================================

`include "dvi_defines.v"

module mips_display (
    input clk,

    input [13:0] display_data,
    input we,

    input [5:0] XPos,
    input [4:0] YPos,
    input valid, 

    output wire [5:0] vga_rgb
);

    reg [2:0] block_colors [2047:0];

    wire [2:0] color = display_data[13:11];

    wire [5:0] block_x_write = display_data[10:5];
    wire [4:0] block_y_write = display_data[4:0];
    
    wire [10:0] read_addr = {YPos, 5'b0} + {YPos, 3'b0} + XPos;

    wire [10:0] write_addr = {block_y_write, 5'b0} + {block_y_write, 3'b0} + block_x_write;

    always @(posedge clk) begin
        if (we)
            block_colors[write_addr] <= color;
    end

    wire [2:0] out_color = block_colors[read_addr];

    assign vga_rgb = valid ? {{2{out_color[2]}}, {2{out_color[1]}}, {2{out_color[0]}}} : 6'd0;

endmodule
