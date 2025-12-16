# Guttersynth → Disting NT Implementation Summary

**Port by:** M. IJzerman
**Original Guttersynth:** Tom Mudd
**Date:** 2025-12-16

---

## Quick Overview

✅ **Feasibility:** YES - The port is feasible with optimizations
📊 **Implementation:** Faust DSP → Disting NT C++ plugin
🎛️ **Configuration:** 1 voice, 2 filter banks, 8 filters per bank (16 total)
⚡ **Status:** v0.1 prototype completed, ready for testing

---

## Files Created

### Core Implementation
- [`distingNT_API-main/faust/examples/guttersynth.dsp`](distingNT_API-main/faust/examples/guttersynth.dsp)
  Main Faust implementation with Disting NT metadata

- [`distingNT_API-main/faust/examples/guttersynth_test.dsp`](distingNT_API-main/faust/examples/guttersynth_test.dsp)
  Test version for Faust IDE (https://faustide.grame.fr/)

### Documentation
- [`distingNT_API-main/faust/examples/guttersynth_README.md`](distingNT_API-main/faust/examples/guttersynth_README.md)
  Comprehensive documentation with version tracking

- [`distingNT_API-main/faust/examples/BUILD_GUTTERSYNTH.md`](distingNT_API-main/faust/examples/BUILD_GUTTERSYNTH.md)
  Build instructions and troubleshooting

### Build System
- [`distingNT_API-main/faust/examples/Makefile.guttersynth`](distingNT_API-main/faust/examples/Makefile.guttersynth)
  Makefile for building the plugin

---

## Key Design Decisions

### Original vs Port Comparison

| Aspect | Original (Max/MSP) | Disting NT Port v0.1 |
|--------|-------------------|---------------------|
| **Oscillators** | 1 per voice (8 voices) | 1 (single voice) |
| **Filter Banks** | 2 per voice | 2 |
| **Filters/Bank** | 24 | 8 |
| **Total Filters** | 48 | 16 |
| **Sample Rate** | 44.1 kHz | 48 kHz |
| **Implementation** | Java (mxj~) | Faust → C++ |
| **CPU Load** | ~450 ops/sample | ~150 ops/sample (est.) |

### Why These Changes?

1. **Reduced filter count (24→8 per bank):**
   - Embedded ARM CPU constraints
   - Filters are 90%+ of computational cost
   - 8 well-tuned filters preserve essential character
   - Leaves headroom for future multi-voice implementation

2. **Single voice initially:**
   - Validate core algorithm first
   - Establish performance baseline
   - Test on actual hardware before scaling up

3. **Faust implementation:**
   - Proven integration with Disting NT
   - ARM compiler optimizations
   - Automatic parameter mapping
   - Easier to test and iterate

---

## Implementation Details

### Core Algorithm

The Duffing oscillator with feedback from filter banks:

```
dy = finalY - (finalY³) - (c·duffY) + gamma·sin(omega·t)
duffY += dy
dx = duffY
duffX = (finalY + dx - duffX_prev) / smoothing
```

Implemented in Faust using recursive feedback operator `~`

### Parameters (11 total)

**Duffing Oscillator:**
1. gamma - Forcing amplitude (0-2)
2. omega - Forcing frequency (0.1-10)
3. c - Damping coefficient (0-1)
4. dt - Time step (0.001-10)

**Filter Banks:**
5. q - Resonance/Q (0.5-100)
6. smoothing - Lowpass amount (1-10)

**Mix:**
7. singleGain - Overall gain (0-2)
8. bank0Gain - Bank 0 mix (0-2)
9. bank1Gain - Bank 1 mix (0-2)

**Effects:**
10. distortionMode - Algorithm selector (0-5)

All include smoothing via `si.smoo` for artifact-free parameter changes.

### Filter Configuration

**Bank 0 frequencies (Hz):**
80, 120, 180, 250, 350, 500, 700, 1000

**Bank 1 frequencies (Hz):**
96, 144, 216, 300, 420, 600, 840, 1200
(Bank 0 × 1.2, as per original)

### Distortion Modes

0. Hard clipping
1. Cubic with clipping
2. atan (tanh-like) ← default
3. atan approximation
4. tanh approximation
5. Sigmoid function

---

## Next Steps

### Immediate (Testing Phase)

1. **Test in Faust IDE:**
   ```
   https://faustide.grame.fr/
   ```
   - Copy `guttersynth_test.dsp` into the IDE
   - Verify audio output and parameter behavior
   - Compare with original Max/MSP version

2. **Build for Disting NT:**
   ```bash
   cd distingNT_API-main/faust/examples/
   make -f Makefile.guttersynth
   ```

3. **Deploy to Hardware:**
   - Copy `guttersynth.o` to SD card
   - Load on Disting NT
   - Test all parameters
   - **Monitor CPU usage carefully**

### Phase 2 (If CPU allows)

- Add audio input forcing (replace sine with external signal)
- Implement filter frequency presets (from filters.txt)
- Add per-filter frequency control
- Optimize distortion algorithms if needed

### Phase 3 (Multi-voice)

- Add configurable voice count (1-4 voices via specifications)
- MIDI note input
- Polyphonic parameter handling
- Further CPU optimization if needed

---

## Testing Checklist

- [ ] Syntax check: `faust guttersynth.dsp -o /dev/null`
- [ ] Test in Faust IDE with `guttersynth_test.dsp`
- [ ] Build for Disting: `make -f Makefile.guttersynth`
- [ ] Load on Disting NT hardware
- [ ] Test Duffing parameters (gamma, omega, c, dt)
- [ ] Test filter parameters (Q, smoothing)
- [ ] Test all 6 distortion modes
- [ ] Test bank mixing (bank0Gain, bank1Gain)
- [ ] Monitor CPU usage (<20% target)
- [ ] Compare output with original Max/MSP version
- [ ] Document any stability issues (NaN checks, resets)

---

## Known Limitations (v0.1)

- ❌ No audio input forcing (sine forcing only)
- ❌ Fixed filter frequencies (no runtime adjustment)
- ❌ No filter presets
- ❌ Single voice only
- ❌ No MIDI input
- ❌ No custom UI
- ❌ Fewer filters than original (16 vs 48)

These are intentional for the minimal prototype. Features will be added incrementally based on CPU performance.

---

## CPU Performance Targets

**Estimated load (single voice, 16 filters):**
- ~150 operations per sample
- At 48kHz: ~7.2 million ops/sec
- Target: <20% CPU on Cortex-M7

**If CPU usage is too high:**
- Reduce filters to 6 per bank (12 total)
- Simplify distortion (use mode 0 or 2 only)
- Reduce parameter smoothing
- Consider fixed-point math in critical sections

**If CPU usage is acceptable:**
- Increase to 12 filters per bank (24 total)
- Add second voice
- Implement audio input forcing
- Add filter presets

---

## References

- **Original repository (forked by jarmitage):** https://github.com/jarmitage/guttersynthesis
- **Disting NT API:** https://github.com/expertsleepersltd/distingNT_API
- **Faust documentation:** https://faust.grame.fr/
- **Faust IDE (testing):** https://faustide.grame.fr/
- **Duffing oscillator theory:** Nonlinear dynamics, chaotic systems

---

## Version History

### v0.1 - Minimal Prototype (2025-12-16)
- Core Duffing oscillator implementation
- 2 filter banks, 8 filters each
- 6 distortion modes
- 11 parameters
- Sine forcing
- Ready for hardware testing

### v0.2 - Planned
- Audio input forcing
- Filter presets
- Enhanced parameter control
- Performance profiling results

### v0.3 - Planned
- Multi-voice support (if CPU allows)
- MIDI input
- Runtime configuration via specifications

---

## Development Notes

### Synchronization Strategy

The two DSP files should be kept in sync:

**guttersynth.dsp (Disting version):**
- Includes Disting metadata (guid, name, description)
- Production version for hardware

**guttersynth_test.dsp (Test version):**
- No Disting metadata
- For testing in Faust IDE
- Should have identical DSP code

**Workflow:**
1. Edit `guttersynth_test.dsp`
2. Test in Faust IDE
3. Copy changes to `guttersynth.dsp`
4. Add back Disting metadata if removed
5. Build for Disting NT

### Code Structure

The implementation uses Faust's recursive feedback operator `~`:

```faust
process = (0, 0, 0) : (duffingSystem ~ (_, _, _)) : (!, !, !, _);
```

This creates a feedback loop with state variables:
- `duffX` - Current oscillator position
- `duffY` - Velocity/derivative
- `t` - Time/phase for sine forcing

The `with` block encapsulates all processing logic cleanly.

---

## Contact & Contributions

**Port Author:** M. IJzerman
**Original Guttersynth:** Tom Mudd

For issues or enhancements, document them alongside the implementation files in this repository.

---

**Last Updated:** 2025-12-16
**Status:** Prototype complete, awaiting hardware testing
