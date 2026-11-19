CXX ?= g++
CXXFLAGS ?= -O2 -std=c++17

.PHONY: all clean
all: build/sta

build/sta: src/sta.cpp
	mkdir -p build
	$(CXX) $(CXXFLAGS) $< -o $@

clean:
	rm -rf build
