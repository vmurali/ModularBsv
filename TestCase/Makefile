.PHONY: all clean

%:
	bsc -unspecified-to 0 -u -verilog -dATS -aggressive-conditions $*.bsv | grep -v '\->' | grep -v "compiling " | grep -v "checking package dependencies" | grep -v "code generation for" | grep -v "Verilog file created:" | grep -v "All packages are up to date" | grep -v "\<wire info\>" | grep -v "\<APackage resets\>" | grep -v "APackage parameters" | grep -v "APackage arguments" | grep -v '\-\- IdProp\>' | iconv -f us-ascii -t us-ascii -c > output

clean:
	rm -f output *.bo *.v
