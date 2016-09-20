all:
	xcrun -sdk macosx clang \
		-std=c99 \
		-Wall \
		-Wextra \
		-Wno-unused-parameter \
		-O0 \
		-DDEBUG \
		-UNDEBUG \
		-fobjc-arc \
		-g \
		-I$(shell xcrun -sdk macosx --show-sdk-path)/usr/include/libxml2 \
		-I../src \
		-lobjc \
		-lxml2 \
		-framework Foundation \
		-o test \
		../src/*.m ./*.m

clean:
	rm -f main test *.o
	rm -rf *.dSYM
