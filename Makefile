.PHONY: clean

%:
	ghc --make -outputdir build $*.hs -o Test

clean:
	rm -rf build Test

.DEFAULT_GOAL :=
