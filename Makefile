.PHONY: clean

%:
	ghc --make -funfolding-use-threshold=16 -O2 -outputdir build $*.hs -o Test

clean:
	rm -rf build Test

.DEFAULT_GOAL :=
