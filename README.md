# Guttersynth for Disting NT - Project Root

**Port by:** M. IJzerman
**Original Guttersynth:** Tom Mudd
**Date:** 2025-12-16
**Status:** v0.1 Prototype - Ready for testing

---

## Project Overview

This project ports the Guttersynth forced damped Duffing oscillator system to run as a Faust-based plugin on the Expert Sleepers Disting NT Eurorack module.

Two versions:

#### guttersynth.dsp / guttersynth.o 
A nice and lean version that can run 2/3 times on the Disting NT

---

## Parameters

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