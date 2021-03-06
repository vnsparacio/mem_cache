`include "mips_defines.v"
//`define COMPTAG		2'd0;
//`define MEMREAD		2'd1;
//`define MEMWRITE	2'd2;
module cache (
    input clk,
    input memclk,
    input [31:0] addr, // byte addresss
    input we,
    input re,
    input rst,
    input [31:0] din,

    output wire [31:0] dout,
    output wire complete
);
    wire reset = 1'b0; //constant to keep reset low
    // when implementing your cache FSM logic
    // you will write and read from these structures
    // containing the valid bits, tag, and data, for each cache
    // block, indexed from 0 to 63
    // you may modify these structures to implement more complicated caches,
    // but their total size must not increase
	
    //FSM STATES - `define did not work so this is a workaround
    reg [2:0] comptag = 3'd0;
    reg [2:0] memread = 3'd1;
    reg [2:0] memwrite = 3'd2;
    reg [2:0] cachewrite = 3'd3;
    reg [2:0] done = 3'd4;


    //FSM state variables
    wire [2:0] state;
    reg [2:0] next_state;
    wire delayed_dram_complete;
    wire [127:0] delayed_dram_out;
    reg [31:0] delayed_dram_word;

    // this will support 64 blocks of 4 words each, for a total of 1KB of
    // cache data storage
    reg valid_bits [63:0];
    reg [21:0] tag_bits [63:0];
    reg [127:0] data_blocks [63:0]; 

    // outputs from DRAM
    wire [127:0] dram_out;
    wire dram_complete;


    //address fields
    wire [21:0] addr_tag = addr[31:10];
    wire [21:0] tag;
    reg [21:0] next_tag;
    wire [5:0] index = addr[9:4];
    wire [1:0] word_offset = addr[3:2]; //offset of word inside block (block has 4 words)
    wire [4:0] byte_offset = addr[3:0];

    wire [21:0] bogus = tag_bits[index];
    wire [127:0] block = data_blocks[index];
    wire valid = valid_bits[index];
    wire hit = (addr_tag === tag_bits[index]); //check if tag bits of addr = tag bits of that index in cache

    reg [31:0] cache_out, dram_word; //cache_out = word read from cache, dram_word = word we want from memory
    reg [127:0] temp_block; //the block we write into memory 
	
    dffr #(3) state_ff(.clk(clk), .r(reset), .d(next_state), .q(state)); //must change reset back to rst
    dffr dram_complete_ff(.clk(clk), .r(reset), .d(dram_complete), .q(delayed_dram_complete));
    dffr #(128) data_ff(.clk(clk), .r(reset), .d(dram_out), .q(delayed_dram_out));
    dffr #(22) tag_ff(.clk(clk), .r(reset), .d(next_tag), .q(tag));


    always @(*) begin
	next_tag = (state == done) ? addr_tag : tag;

	case (word_offset) 
		2'b00: 
			begin 
				cache_out = block[31:0];
				dram_word = dram_out[31:0];
				delayed_dram_word = delayed_dram_out[31:0];
				temp_block = {block[127:32], din};
				
			end
		2'b01: 
			begin
				cache_out = block[63:32];
				dram_word = dram_out[63:32];
				delayed_dram_word = delayed_dram_out[63:32];
				temp_block = {block[127:64], din, block[31:0]};
			end
		2'b10: 
			begin
				cache_out = block[95:64];
				dram_word = dram_out[95:64];
				delayed_dram_word = delayed_dram_out[95:64];
				temp_block = {block[127:96], din, block[63:0]};
			end
		2'b11: 
			begin
				cache_out = block[127:96];
				dram_word = dram_out[127:96];
				delayed_dram_word = delayed_dram_out[127:96];
				temp_block = {din, block[95:0]};
			end
		default: cache_out = 32'b0;
	endcase

   	//FSM State logic
	casex ({state, valid, hit, re, we, dram_complete})
		{comptag, 5'b00100}: 
			begin
				next_state = memread;		//valid bit = 0 so treat as read miss
				valid_bits[index] = 1'b1; 	//now we can set it to 1
			end
		{comptag, 5'b0x010}: 
			begin
				next_state = memwrite;		//valid bit = 0 so treat as write miss
				valid_bits[index] = 1'b1;
			end	
		{comptag, 5'b101xx}: next_state = memread;	//read miss
		{comptag, 5'b10x1x}: next_state = memwrite;	//write miss
		{comptag, 5'b11x1x}:				//write hit: write to cache then switch to memwrite stage
			begin
				next_state = memwrite;
				data_blocks[index] = temp_block;
			end
		{comptag, 5'b111xx}: next_state = done; 	//read hit
		{memread, 5'bxxxx1}: 
			begin
				next_state = cachewrite;	//read miss after writing to mem
				tag_bits[index] = tag;
			end
		{memwrite, 5'bxxxx1}: 
			begin
				next_state = done;	//writing to word to mem
				tag_bits[index] = tag;
			end
		{cachewrite, 5'bxxxxx}: //writing to cache will only take on cycle
			begin
				next_state = done; 
				data_blocks[index] = dram_out; //on read miss, write block from mem into cache
			end
		{done, 5'bxxxxx}: next_state = comptag; //go back to start state
		default: next_state = state;
	endcase
    end





    //USE THIS SYNCHRONOUS BLOCK TO ASSIGN THE INPUTS TO DRAM
    
    // inputs to dram should be regs when assigned in a state machine
    reg dram_we, dram_re;
    reg [`MEM_DEPTH-3:0] dram_addr;
    reg [127:0] dram_in;
    //reg cache_complete;

    always @(posedge clk) begin	dram_we = (next_state == memwrite);
	dram_re = (next_state == memread);
	dram_addr = addr[`MEM_DEPTH+1:4];
	dram_in = temp_block;
    end
    
    

    // COMMENT OUT THIS CONTINUOUS CODE WHEN IMPLEMENTING YOUR CACHE
    // The code below implements the cache module in the trivial case when
    // we don't use a cache and we use only the first word in each memory
    // block, (which are four words each).
    /*

    // just pass we and re straignt to the DRAM
    wire dram_we = we;
    wire dram_re = re;


    wire [`MEM_DEPTH-3:0] dram_addr = addr[`MEM_DEPTH+1:4];
    wire [127:0] dram_in = {96'd0, din};
    wire [31:0] cache_dout = dram_out[31:0];

    // the cache is done when DRAM is done
    wire cache_complete = dram_complete;

    */

    
    dataram dram (.clk(clk),
                  .memclk(memclk),
                  .rst(rst),
                  .we(dram_we),
                  .re(dram_re),
                  .addr(dram_addr),
                  .din(dram_in),
                  .dout(dram_out),
                  .complete(dram_complete));
    
    //if in comptag stage: return word from cache (cache_out)
    //if in cachewrite stage: return the delayed dram word
    //we only care about these two cases because dout only matters for read hits or read misses
    //on read hits, you'll have the data in the comptag stage, on read misses you'll have the data in cachewrite stage
    assign dout = (state == comptag) ? cache_out : delayed_dram_word;


    assign complete = (state == done) || ~(re | we);

endmodule
