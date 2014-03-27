// dffarre: D flip-flop with active high enable and asynchronous reset
// and synchronous reset
// Parametrized width; default of 1
module dffarre #(parameter WIDTH = 1) (
    input clk,
    input ar,
    input r,
    input en,
    input [WIDTH-1:0] d,
    output reg [WIDTH-1:0] q
);

    always @(posedge clk or negedge ar)
        if (~ar)
            q <= {WIDTH{1'b0}};
        else if (r)
            q <= {WIDTH{1'b0}};
        else if (en)
            q <= d;
        else
            q <= q;

endmodule
