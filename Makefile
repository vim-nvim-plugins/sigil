# make           fetch pinned sources (first time), build bin/sigil
# make test      golden tests in tests/ (UPDATE=1 make test rewrites expected.txt)
# make clean     remove build output · make distclean  also the fetched sources
all:
	@sh tools/build.sh

test: all
	@sh tests/run.sh

clean:
	rm -rf build bin

distclean: clean
	rm -rf deps

.PHONY: all test clean distclean
