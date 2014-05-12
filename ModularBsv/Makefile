.PHONY: clean

%:
	ghc -prof --make -rtsopts -outputdir build $*.hs -o Test

clean:
	rm -rf build ModularBsv

.DEFAULT_GOAL :=
