.PHONY: all clean

all:
	bsc -u -verilog -dATS -aggressive-conditions TestBench.bsv | grep -v '\->' | grep -v "compiling " | grep -v "checking package dependencies" | grep -v "code generation for" | grep -v "Verilog file created:" | grep -v "All packages are up to date" > output

clean:
	rm output *.bo *.v
