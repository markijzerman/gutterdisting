# Guttersynth for Disting NT - Project Root

**Port by:** M. IJzerman
**Original Guttersynth:** Tom Mudd
**Date:** 2025-12-16
**Status:** v0.1 Prototype - Ready for testing

---

## Project Overview

This project ports the Guttersynth forced damped Duffing oscillator system to run as a Faust-based plugin on the Expert Sleepers Disting NT Eurorack module.

**Original:** 1 Duffing oscillator + 48 bandpass filters (2 banks × 24) per voice
**Port v0.1:** 1 Duffing oscillator + 16 bandpass filters (2 banks × 8) - single voice

---

## Project Structure

```
guttersynth_disting_port/
├── README.md                       ← You are here (project overview)
│
├── src/                            ← Source Code
│   ├── guttersynth.dsp            ← Main implementation (for Disting NT)
│   └── guttersynth_test.dsp       ← Test version (for Faust IDE)
│
├── build/                          ← Build System
│   └── Makefile                   ← Build commands
│
├── docs/                           ← Documentation
│   ├── IMPLEMENTATION.md          ← Detailed implementation docs
│   ├── BUILD_GUTTERSYNTH.md       ← Build instructions
│   └── IMPLEMENTATION_SUMMARY.md  ← Quick reference
│
└── tests/                          ← Test Files (future)
    └── (test recordings, configs)
```

---

## Quick Start

### 1. Test in Faust IDE (Browser, No Installation)

**URL:** https://faustide.grame.fr/

1. Open the Faust IDE in your browser
2. Copy the contents of [`src/guttersynth_test.dsp`](src/guttersynth_test.dsp)
3. Paste into the IDE editor
4. Click "Run" to compile
5. Use the web audio player to hear the output
6. Adjust parameters in real-time:
   - **gamma** - Forcing amplitude (try 0.05-0.5)
   - **omega** - Forcing frequency (try 0.5-3)
   - **c** - Damping (try 0.1-0.5)
   - **dt** - Time step (try 0.5-2)
   - **Q** - Filter resonance (try 10-50)
   - **distortionMode** - Try modes 0-5

### 2. Build for Disting NT

**Requirements:**
- Faust compiler
- ARM GCC toolchain (`arm-none-eabi-c++`)
- Disting NT API (already present in parent directory)

**Build commands:**
```bash
cd build/
export NT_API_PATH=/Users/markijzerman/Dropbox/DISTING/guttersynth_on_disting/distingNT_API-main
export FAUSTARCH=/path/to/faust/architecture
make
```

**Output:** `guttersynth.o` (ready to load on Disting NT)

See [`docs/BUILD_GUTTERSYNTH.md`](docs/BUILD_GUTTERSYNTH.md) for detailed build instructions.

### 3. Deploy to Disting NT

1. Copy `guttersynth.o` to your Disting NT SD card
2. Insert SD card into Disting NT
3. Load the plugin via the module menu
4. Configure audio I/O routing
5. **Monitor CPU usage carefully**

---

## Parameters (11 total)

### Duffing Oscillator (4 parameters)
- **gamma** - Forcing amplitude (0-2, default: 0.1)
- **omega** - Forcing frequency (0.1-10, default: 1.25)
- **c** - Damping coefficient (0-1, default: 0.3)
- **dt** - Time step (0.001-10, default: 1)

### Filters (2 parameters)
- **Q** - Resonance (0.5-100, default: 30)
- **smoothing** - Lowpass amount (1-10, default: 1)

### Mix (4 parameters)
- **singleGain** - Overall gain (0-2, default: 0.5)
- **bank0Gain** - Bank 0 mix (0-2, default: 1)
- **bank1Gain** - Bank 1 mix (0-2, default: 0)

### Effects (1 parameter)
- **distortionMode** - Algorithm 0-5 (default: 2=atan)
  - 0: Hard clipping
  - 1: Cubic with clipping
  - 2: atan (tanh-like)
  - 3: atan approximation
  - 4: tanh approximation
  - 5: Sigmoid function

---

## Documentation

- **[IMPLEMENTATION.md](docs/IMPLEMENTATION.md)** - Full implementation details, version tracking, parameter specs
- **[BUILD_GUTTERSYNTH.md](docs/BUILD_GUTTERSYNTH.md)** - Build instructions, environment setup, troubleshooting
- **[IMPLEMENTATION_SUMMARY.md](docs/IMPLEMENTATION_SUMMARY.md)** - Quick reference, design decisions, testing checklist

---

## Source Files

### Main Implementation
**[src/guttersynth.dsp](src/guttersynth.dsp)** (154 lines)
- Includes Disting NT metadata (guid, name, description)
- Production version for hardware
- Build target: `guttersynth.o`

### Test Version
**[src/guttersynth_test.dsp](src/guttersynth_test.dsp)** (147 lines)
- No Disting metadata
- For testing in Faust IDE
- Identical DSP code to main version

**Important:** Keep these files in sync. Changes should be made to `guttersynth_test.dsp` first (test in IDE), then copied to `guttersynth.dsp` (keeping Disting metadata intact).

---

## Development Workflow

### Recommended Process

1. **Edit** `src/guttersynth_test.dsp`
2. **Test** in Faust IDE (https://faustide.grame.fr/)
3. **Listen** to audio output and verify parameters
4. **Copy changes** to `src/guttersynth.dsp`
5. **Verify** Disting metadata is intact (lines 10-12)
6. **Build** with `make` in `build/` directory
7. **Deploy** to Disting NT hardware
8. **Profile** CPU usage and behavior
9. **Document** findings and update version notes

### Synchronization

Both `.dsp` files should have identical DSP code except for these lines:

**guttersynth.dsp only:**
```faust
declare guid "GutS";
declare name "Gutter Synth";
declare description "Duffing oscillator with resonator banks";
```

---

## Current Status

### ✅ Completed (v0.1)
- Core Duffing oscillator implementation
- 2 filter banks, 8 filters per bank (16 total)
- 6 distortion modes
- 11 parameters with smoothing
- Faust DSP source code
- Build system (Makefile)
- Documentation

### 🔄 Next Steps
- [ ] Test DSP code in Faust IDE
- [ ] Build for Disting NT
- [ ] Deploy to hardware
- [ ] Measure CPU usage
- [ ] Compare with original Max/MSP version
- [ ] Document performance findings

### 🎯 Future Enhancements (v0.2+)
- Audio input forcing (replace sine with external signal)
- Filter frequency presets
- Per-filter frequency control
- Multiple voices (2-4 configurable)
- MIDI input
- Custom UI
- Runtime filter count adjustment

---

## Performance Targets

**Estimated (single voice, 16 filters):**
- ~150 operations per sample
- At 48kHz: ~7.2 million ops/sec
- **Target: <20% CPU on ARM Cortex-M7**

**If CPU usage is too high:**
- Reduce to 6 filters per bank (12 total)
- Simplify distortion (modes 0 or 2 only)
- Remove parameter smoothing
- Use fixed-point math in critical sections

**If CPU usage is acceptable:**
- Increase to 12 filters per bank (24 total)
- Add second voice
- Implement audio input forcing
- Add filter presets

---

## Related Directories

This project references:

**Parent directory:** `/Users/markijzerman/Dropbox/DISTING/guttersynth_on_disting/`

Contains:
- **`guttersynthesis-master/`** - Original Max/MSP implementation (Tom Mudd)
  - Source: `gutterOsc.java` - Reference implementation
  - Presets: `filters.txt` - Filter bank configurations

- **`distingNT_API-main/`** - Disting NT plugin API (Expert Sleepers)
  - Build tool: `faust/faust2distingnt`
  - Architecture: `faust/nt_arch.cpp`
  - Examples: `examples/` - Reference plugins
  - Headers: `include/distingnt/api.h`

**Workflow note:** Source files in this project (`src/`) are also maintained in `distingNT_API-main/faust/examples/` for integration with the Disting build system. Keep both locations in sync.

---

## Testing Checklist

### Phase 1: DSP Validation
- [ ] Syntax check: `faust src/guttersynth.dsp -o /dev/null`
- [ ] Test in Faust IDE with `src/guttersynth_test.dsp`
- [ ] Verify all parameters respond correctly
- [ ] Test all 6 distortion modes
- [ ] Check for audio artifacts or instability

### Phase 2: Build & Deploy
- [ ] Build successfully: `cd build && make`
- [ ] No compiler warnings or errors
- [ ] Output file created: `guttersynth.o`
- [ ] Load on Disting NT hardware
- [ ] Plugin appears in module menu

### Phase 3: Hardware Testing
- [ ] Test Duffing parameters (gamma, omega, c, dt)
- [ ] Test filter parameters (Q, smoothing)
- [ ] Test all distortion modes on hardware
- [ ] Test bank mixing (bank0Gain, bank1Gain)
- [ ] Monitor CPU usage (<20% target)
- [ ] Test for NaN/stability issues
- [ ] Compare output with original Max/MSP version

### Phase 4: Documentation
- [ ] Record CPU usage measurements
- [ ] Document stable parameter ranges
- [ ] Update version notes with findings
- [ ] Create usage examples
- [ ] Document any discovered issues

---

## References

- **Original Guttersynth (Tom Mudd):** https://github.com/jarmitage/guttersynthesis
- **SuperCollider port:** https://github.com/madskjeldgaard/guttersynth-sc
- **Disting NT API:** https://github.com/expertsleepersltd/distingNT_API
- **Faust language:** https://faust.grame.fr/
- **Faust IDE:** https://faustide.grame.fr/
- **Duffing oscillator theory:** Nonlinear dynamics, chaotic systems literature

---

## Version History

### v0.1 - Minimal Prototype (2025-12-16)
- Initial implementation
- 1 voice, 2 filter banks, 8 filters per bank
- Core Duffing oscillator with sine forcing
- 6 distortion modes, 11 parameters
- Ready for hardware testing

### v0.2 - Planned
- Audio input forcing
- Filter presets
- Performance profiling results
- Optimizations based on hardware testing

### v0.3 - Planned
- Multi-voice support (if CPU allows)
- MIDI input
- Runtime configuration

---

## License & Attribution

**Original Guttersynth:** Tom Mudd
**Disting NT Port:** M. IJzerman (2025)

This is a port/adaptation. Please respect the original author's work and any licensing terms.

---

**Last Updated:** 2025-12-16
**Current Version:** v0.1 (Prototype)
**Status:** Ready for testing
