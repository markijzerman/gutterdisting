# Building Guttersynth for Disting NT

## Prerequisites 

1. **Faust compiler** - Install from https://faust.grame.fr/
2. **ARM GCC toolchain** - `arm-none-eabi-gcc` and `arm-none-eabi-c++`
3. **Environment variables** set up for Disting NT API

## Environment Setup

The `faust2distingnt` build script requires these environment variables:

```bash
# Add to your ~/.bashrc or ~/.zshrc

# Path to Faust architecture files
export FAUSTARCH=/path/to/faust/architecture

# Path to Disting NT API
export NT_API_PATH=/Users/markijzerman/Dropbox/DISTING/guttersynth_on_disting/distingNT_API-main

# Add faust to PATH
export PATH=$PATH:/path/to/faust/bin
```

## Quick Build

From the `distingNT_API-main/faust/examples/` directory:

```bash
# Build guttersynth.dsp to guttersynth.o
../faust2distingnt guttersynth.dsp guttersynth.o
```

## Manual Build Steps

If you prefer to build manually:

```bash
# 1. Generate C++ from Faust DSP
faust -a $FAUSTARCH/nt_arch.cpp -uim -nvi -mem \
    -o guttersynth.cpp guttersynth.dsp

# 2. Process metadata and remove small arrays
python3 $FAUSTARCH/remove_small_arrays.py guttersynth.cpp
python3 $FAUSTARCH/apply_metadata.py guttersynth.cpp

# 3. Compile to object file
arm-none-eabi-c++ -std=c++11 \
    -mcpu=cortex-m7 \
    -mfpu=fpv5-d16 \
    -mfloat-abi=hard \
    -mthumb \
    -fno-exceptions \
    -Os \
    -fPIC \
    -Wall \
    -I$NT_API_PATH/include \
    -c -o guttersynth.o guttersynth.cpp

# 4. Clean up
rm guttersynth.cpp
```

## Faust Compiler Flags Explained

- `-a $FAUSTARCH/nt_arch.cpp` - Use Disting NT architecture wrapper
- `-uim` - User interface macros
- `-nvi` - No virtual methods (lighter code)
- `-mem` - Custom memory manager (for DTC/DRAM allocation)

## Testing the DSP Code

### Option 1: Faust Online IDE (Recommended for DSP testing)

1. Go to https://faustide.grame.fr/
2. Copy the contents of `guttersynth_test.dsp` into the editor
3. Click "Run" to compile and test
4. Use the web audio player to hear the output
5. Adjust parameters in real-time

**Note:** Use `guttersynth_test.dsp` for web testing (no Disting-specific metadata)

### Option 2: Local Faust Testing

```bash
# Compile to standalone C++ test application
faust2caqt guttersynth_test.dsp

# Or compile to JACK audio app
faust2jack guttersynth_test.dsp

# Run the generated application
./guttersynth_test
```

### Option 3: Syntax Check Only

```bash
# Check if DSP file compiles without errors
faust guttersynth.dsp -o /dev/null
```

## Expected Output

If successful, you'll get:

- `guttersynth.o` - ARM object file ready to load onto Disting NT
- No compilation errors or warnings

## Loading onto Disting NT

1. Copy `guttersynth.o` to the SD card (see Disting NT documentation)
2. Insert SD card into Disting NT
3. Load the plugin via the Disting menu
4. Configure I/O routing and parameters

## Troubleshooting

### "faust: command not found"

Install Faust from https://faust.grame.fr/ or via package manager:
```bash
# macOS
brew install faust

# Linux
sudo apt-get install faust
```

### "arm-none-eabi-c++: command not found"

Install ARM GCC toolchain:
```bash
# macOS
brew install --cask gcc-arm-embedded

# Linux
sudo apt-get install gcc-arm-none-eabi
```

### "Cannot find nt_arch.cpp"

Set the `FAUSTARCH` environment variable to point to your Faust architecture directory.

### Compilation errors in generated C++

This could indicate:
- Invalid Faust DSP code
- Incompatible Faust library functions
- Try testing in Faust IDE first to isolate DSP vs platform issues

## Development Workflow

1. **Edit** `guttersynth_test.dsp` in Faust IDE
2. **Test** parameters and audio output in browser
3. **Sync changes** to `guttersynth.dsp` (add back Disting metadata)
4. **Build** with `faust2distingnt`
5. **Deploy** to Disting NT hardware
6. **Profile** CPU usage and optimize if needed

## Performance Monitoring

Once loaded on Disting NT, monitor CPU usage:

- Check Disting NT's CPU meter
- If CPU is too high (>80%), consider:
  - Reducing filter count (8 → 6 per bank)
  - Simplifying distortion algorithms
  - Removing smoothing on some parameters

## Next Steps

After successful build:
- [ ] Test on actual Disting NT hardware
- [ ] Profile CPU usage
- [ ] Adjust filter count if needed
- [ ] Test all parameters and distortion modes
- [ ] Document presets and usage patterns
