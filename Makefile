.PHONY: all clean

all:
	ghc --make -outputdir build ModularBsv.hs

clean:
	rm -rf build ModularBsv
