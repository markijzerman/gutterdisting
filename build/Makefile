# Makefile for Guttersynth Disting NT Plugin
# Usage: cd build && make

# Ensure these environment variables are set:
# - FAUSTARCH: Path to Faust architecture files
# - NT_API_PATH: Path to Disting NT API root (or use default below)

# Default paths (can be overridden with environment variables)
NT_API_PATH ?= ../../distingNT_API-main
FAUST2DISTINGNT = $(NT_API_PATH)/faust/faust2distingnt

# Source and output files
SRC_DIR = ../src
DSP_FILE = $(SRC_DIR)/guttersynth.dsp
TEST_DSP_FILE = $(SRC_DIR)/guttersynth_test.dsp
OUTPUT = guttersynth.o

# Check environment (FAUSTARCH still required)
ifndef NT_API_PATH
$(error NT_API_PATH is not set. Please set it or use default: $(NT_API_PATH))
endif

ifndef FAUSTARCH
$(warning FAUSTARCH is not set. This may cause build failures)
endif

.PHONY: all clean test check help

# Default target
all: $(OUTPUT)

# Build Disting NT plugin
$(OUTPUT): $(DSP_FILE)
	@echo "Building Guttersynth for Disting NT..."
	$(FAUST2DISTINGNT) $(DSP_FILE) $(OUTPUT)
	@echo "Success! Output: $(OUTPUT)"

# Test DSP syntax (requires faust in PATH)
check:
	@echo "Checking Faust DSP syntax..."
	@faust $(DSP_FILE) -o /dev/null && echo "✓ guttersynth.dsp syntax OK"
	@faust $(TEST_DSP_FILE) -o /dev/null && echo "✓ guttersynth_test.dsp syntax OK"

# Build test version for local audio (requires faust2jack or faust2caqt)
test: $(TEST_DSP_FILE)
	@echo "Building test version for local audio..."
	@if command -v faust2jack >/dev/null 2>&1; then \
		faust2jack $(TEST_DSP_FILE); \
		echo "✓ Built JACK application: ./$(basename $(TEST_DSP_FILE))"; \
	elif command -v faust2caqt >/dev/null 2>&1; then \
		faust2caqt $(TEST_DSP_FILE); \
		echo "✓ Built CoreAudio application: ./$(basename $(TEST_DSP_FILE))"; \
	else \
		echo "✗ Neither faust2jack nor faust2caqt found"; \
		echo "  Install Faust to build test applications"; \
		exit 1; \
	fi

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	rm -f $(OUTPUT)
	rm -f guttersynth.cpp
	rm -f guttersynth_test
	rm -rf guttersynth_test.app
	@echo "Clean complete"

# Show help
help:
	@echo "Guttersynth for Disting NT - Build System"
	@echo ""
	@echo "Targets:"
	@echo "  make all    - Build guttersynth.o for Disting NT (default)"
	@echo "  make check  - Syntax check both .dsp files"
	@echo "  make test   - Build standalone test application"
	@echo "  make clean  - Remove build artifacts"
	@echo "  make help   - Show this help"
	@echo ""
	@echo "Requirements:"
	@echo "  - faust compiler in PATH"
	@echo "  - arm-none-eabi-c++ in PATH"
	@echo "  - NT_API_PATH environment variable set"
	@echo "  - FAUSTARCH environment variable set"
	@echo ""
	@echo "Quick start:"
	@echo "  cd build/"
	@echo "  export FAUSTARCH=/path/to/faust/architecture"
	@echo "  make"
	@echo ""
	@echo "Default NT_API_PATH: ../../distingNT_API-main"
