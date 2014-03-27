SHELL := /usr/bin/env bash

# build using the standard testbench
default:
	iverilog -Wall -o mipstest -ysrc -ylib -Iinclude sim/mips_testbench.v

# run the standard testbench
test: clean default
	./mipstest <<< "finish"

# open the waveform based on the standard testbench
wave: test
	gtkwave mipstest.vcd waveformat.gtkw &

# build using the text-output testbench
textbench:
	iverilog -Wall -o mipstest -ysrc -ylib -Iinclude sim/mips_testbench_text.v

textbench2:
	iverilog -Wall -o mipstest -ysrc -ylib -Iinclude sim/mips_testbench_text2.v

# run the text output testbench
text: clean textbench
	./mipstest <<< "finish"

text2: clean textbench2
	./mipstest <<< "finish"

# build using the very long testbench
long:
	iverilog -Wall -o mipstest -ysrc -ylib -Iinclude sim/mips_testbench_long.v

# open the display simulator that reads display output from the very long testbench
display: clean long
	python dvi-display.py display.ppm & ./mipstest <<< "finish"

# remove all extraneous files (executable, vardump, display)
clean:
	rm -rf mipstest mipstest.vcd display.ppm
