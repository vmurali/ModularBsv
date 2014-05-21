.PHONY: clean all

all:
	ghc --make -funfolding-use-threshold=16 -O -outputdir build ModularBsv.hs

clean:
	rm -rf build ModularBsv

.DEFAULT_GOAL := all
