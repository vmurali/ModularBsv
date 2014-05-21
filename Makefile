.PHONY: clean

%:
	ghc --make -O2 -outputdir build $*.hs -o Test

clean:
	rm -rf build Test

.DEFAULT_GOAL :=
