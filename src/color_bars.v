/*******************************************************************************
* Module: color_bars.v
* Author: David Gal, David Schneider
* Email: david.gal84@gmail.com, dns@stanford.edu
* Project: EE108A DVI
* Description: Generates test color bars for the DVI output
* 
* Updated: 2012/01/24
*******************************************************************************/

`include "dvi_defines.v"

module color_bars(
    input [`log2NUM_COLS-1:0] x,
    input [`log2NUM_ROWS-1:0] y,
    output reg [7:0] r,
    output reg [7:0] g,
    output reg [7:0] b
);

    /* Generate display */
    always @(*) begin
        r = 255;
        g = 255;
        b = 255;
        if ((y >= 0) & (y < 120)) begin
            if ((x >= 0) & (x < 160)) begin
                r = 255;
                g = 0;
                b = 0;
            end
            if ((x >= 160) & (x < 320)) begin
                r = 0;
                g = 255;
                b = 0;
            end
            if ((x >= 320) & (x < 480)) begin
                r = 0;
                g = 0;
                b = 255;
            end
            if ((x >= 480) & (x < 640)) begin
                r = 255;
                g = 255;
                b = 0;
            end
        end

        if ((y >= 120) & (y <240)) begin
            if ((x >= 0) & (x < 160)) begin
                r = 0;
                g = 255;
                b = 255;
            end
            if ((x >= 160) & (x < 320)) begin
                r = 0;
                g = 0;
                b = 255;
            end
            if ((x >= 320) & (x < 480)) begin
                r = 255;
                g = 0;
                b = 0;
            end
            if ((x >= 480) & (x < 640)) begin
                r = 0;
                g = 255;
                b = 0;
            end
        end

        if ((y >=240) & (y < 360)) begin
            r = 0;
            g = 0;
            b = 0;
        end

        if (y > 512) begin
            r = x[7:0];
            g = x[8:1];
            b = x[9:2];
        end

        /* Corners */
        if ((x==0 | x==`NUM_COLS-1) & (y==0 | y==`NUM_ROWS-1)) begin
            r = {8{x==0}};
            g = {8{x==0}};
            b = {8{x==0}};
        end
    end
endmodule
