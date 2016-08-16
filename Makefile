all:
	xcrun -sdk macosx clang \
		-std=c99 \
		-Wall \
		-Wextra \
		-O0 \
		-DDEBUG \
		-UNDEBUG \
		-fobjc-arc \
		-g \
		-I$(shell xcrun -sdk macosx --show-sdk-path)/usr/include/libxml2 \
		-lobjc \
		-lxml2 \
		-framework Foundation \
		-o test \
		*.m

clean:
	rm -f main test *.o
	rm -rf *.dSYM
