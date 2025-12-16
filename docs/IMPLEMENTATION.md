# Guttersynth for Disting NT

Port of the Guttersynth forced damped Duffing oscillator system to the Expert Sleepers Disting NT module.

**Original Guttersynth:** Tom Mudd
**Disting NT Port:** M. IJzerman

## Original Implementation (Max/MSP - Java)

**Source:** `guttersynthesis-master/gutterOsc.java`

### Architecture
- **Oscillators:** 1 Duffing oscillator per voice (8 voices typical in full Max patch)
- **Filter Banks:** 2 banks per voice
- **Filters per Bank:** 24 bandpass biquad filters
- **Total Filters:** 48 filters per voice (2 × 24)
- **Sample Rate:** 44.1 kHz
- **Implementation:** Java (mxj~) for Max/MSP

### Core Algorithm
```
Duffing Equation (per sample):
  dy = finalY - (finalY³) - (c·duffY) + gamma·sin(omega·t)
  OR
  dy = finalY - (finalY³) - (c·duffY) + gamma·audioInput

  duffY += dy
  dx = duffY
  duffX = lowpass(finalY + dx, duffX, smoothing)
```

### Parameters (8 audio-rate inlets)
1. **gamma** - Forcing amplitude (0-2, default: 0.1)
2. **omega** - Forcing frequency for sine forcing (0.1-10, default: 1.25)
3. **c** - Damping coefficient (0-1, default: 0.3)
4. **dt** - Time step / integration rate (0.001-0.1, default: 1)
5. **singleGain** - Overall gain control
6. **audioInput** - External audio forcing signal
7. **gains[0]** - Gain for filter bank 0 (default: 1)
8. **gains[1]** - Gain for filter bank 1 (default: 0)

### Message-based Controls
- **Q** - Filter resonance (0.5-30, default: 30)
- **smoothing** - Lowpass smoothing (1-5, 1=none, 5=heavy)
- **distortionMethod** - Distortion algorithm (0-5):
  - 0: Hard clipping
  - 1: Cubic with clipping
  - 2: atan (tanh-like)
  - 3: atan approximation
  - 4: tanh approximation
  - 5: Sigmoid function
- **enableAudioInput** - Toggle between sine forcing and audio input
- **toggleFilters** - Enable/disable filter banks
- **filterCount** - Dynamically change number of filters (runtime)

### Filter Configuration
- **Frequencies:** Configurable per filter, presets available
- **Q values:** Shared across all filters per bank
- **Filter type:** Bandpass biquad (IIR, second-order)

### Computational Load (Original)
- **Per voice:** ~450 operations/sample
  - 48 biquad filters: ~432 ops
  - Duffing: ~20 ops
  - Distortion: ~15 ops
- **8 voices:** ~3600 ops/sample
- **At 44.1kHz:** ~159 million ops/sec (desktop CPU)

---

## Disting NT Implementation (Faust)

**Target:** Expert Sleepers Disting NT (ARM Cortex-M7, 48kHz)

### Version History

#### v0.1 - Minimal Prototype (CURRENT)
**Status:** In development

**Architecture:**
- **Oscillators:** 1 Duffing oscillator (single voice)
- **Filter Banks:** 2 banks
- **Filters per Bank:** 8 filters (reduced from 24)
- **Total Filters:** 16 filters (vs 48 in original)
- **Sample Rate:** 48 kHz
- **Implementation:** Faust DSP → C++

**Implemented Parameters:**
- [ ] gamma - Forcing amplitude
- [ ] omega - Forcing frequency
- [ ] c - Damping coefficient
- [ ] dt - Time step
- [ ] Q - Filter resonance
- [ ] smoothing - Lowpass amount
- [ ] singleGain - Overall gain
- [ ] bank0Gain - Bank 0 mix
- [ ] bank1Gain - Bank 1 mix
- [ ] distortionMethod - Distortion type (enum)
- [ ] audioInput - Enable audio-rate forcing

**Filter Configuration:**
- Fixed frequencies (initial implementation)
- 8 filters per bank (tuned to essential resonances)

**Not Yet Implemented:**
- Runtime filter count adjustment
- Per-filter frequency control
- MIDI input
- Multiple voices
- Custom UI

**Estimated CPU Load:**
- ~150 ops/sample (1 voice, 16 filters)
- At 48kHz: ~7.2 million ops/sec
- **Target: <20% CPU on Cortex-M7**

---

#### v0.2 - Enhanced (PLANNED)
**Target Features:**
- Add missing distortion modes
- Per-filter frequency control via parameters
- Filter bank presets
- Audio input forcing
- Improved parameter smoothing

---

#### v0.3 - Multi-Voice (PLANNED)
**Target Features:**
- Configurable voice count (1-4 voices) via specifications
- MIDI note input
- Per-voice parameter modulation
- CPU profiling and optimization

**Constraints:**
- Voice count determined at plugin load time
- Maximum voices depends on CPU performance testing

---

## Design Decisions & Rationale

### Why Reduce Filter Count?
**Original:** 48 filters per voice (2 × 24)
**Disting:** 16 filters per voice (2 × 8)

- **CPU constraints:** Embedded ARM vs desktop CPU
- **Filter dominance:** Filters are 90%+ of computational cost
- **Perceptual trade-off:** 8 well-tuned filters capture essential character
- **Scalability:** Leaves headroom for multiple voices

### Why Faust?
- Proven integration with Disting NT (`faust2distingnt` tool)
- Compiler optimizations for ARM
- Automatic parameter mapping to Disting UI
- Clean DSP expression
- Faster prototyping than C++

### Why Start with Single Voice?
- Validate core algorithm first
- Establish performance baseline
- Ensure Duffing oscillator behavior is correct
- Iterative development approach

---

## Building

```bash
# From distingNT_API-main/faust/examples/
faust2distingnt guttersynth.dsp guttersynth.o

# Or via Makefile (when added)
make guttersynth
```

## Testing Plan

### Phase 1: Core Algorithm
- [ ] Verify Duffing oscillator behavior matches original
- [ ] Test sine forcing (gamma, omega, c, dt parameters)
- [ ] Validate filter bank output
- [ ] Compare waveforms with Max/MSP version

### Phase 2: Parameters
- [ ] Test all parameter ranges
- [ ] Verify distortion modes
- [ ] Test audio input forcing
- [ ] Test filter bank mixing

### Phase 3: Performance
- [ ] Measure CPU usage on actual Disting NT hardware
- [ ] Profile hot spots
- [ ] Optimize if needed
- [ ] Determine multi-voice feasibility

### Phase 4: Enhancement
- [ ] Add filter presets
- [ ] Implement runtime configuration
- [ ] Add custom UI (if needed)
- [ ] Documentation and examples

---

## References

- **Original Guttersynth by Tom Mudd:** https://github.com/jarmitage/guttersynthesis
- **SuperCollider port:** https://github.com/madskjeldgaard/guttersynth-sc
- **Disting NT API:** https://github.com/expertsleepersltd/distingNT_API
- **Duffing Oscillator:** Forced damped nonlinear oscillator, chaotic dynamics
- **Biquad filters:** http://www.musicdsp.org/files/biquad.c

---

## Notes

- The Disting NT runs at 48kHz vs original 44.1kHz (minimal impact)
- Filter state stored in DTC (fast memory) for performance
- Parameter smoothing handled by Faust's `si.smoo` where appropriate
- Output scaled to ±1.0 for Eurorack compatibility

---

**Last Updated:** 2025-12-16
**Port Author:** M. IJzerman
**Original Guttersynth:** Tom Mudd
