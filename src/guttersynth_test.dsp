// Guttersynth - 8 Coupled Duffing Oscillators
// Based on MaxMSP version architecture with SC-style signal flow
// Port by M. IJzerman
// Original Guttersynth: Tom Mudd
//
// 8 interrelated Duffing oscillators with filter banks
// Each voice has different root note and panning
//
// Try it at: https://faustide.grame.fr/

import("stdfaust.lib");

//==============================================================================
// PARAMETERS
//==============================================================================

// Duffing oscillator parameters
gamma = hslider("h:[0]Duffing/[0]gamma", 0.1, 0, 2, 0.001) : si.smoo;
omega = hslider("h:[0]Duffing/[1]omega", 1.25, 0.1, 10, 0.01) : si.smoo;
cBase = hslider("h:[0]Duffing/[2]c (damping)", 0.3, 0, 1, 0.001) : si.smoo;
dt = hslider("h:[0]Duffing/[3]dt", 1, 0.001, 10, 0.001) : si.smoo;
cMod = hslider("h:[0]Duffing/[4]c modulation", 0.0, 0, 1, 0.01) : si.smoo;

// Filter parameters
filterQ = hslider("h:[1]Filters/[0]Q", 30, 0.5, 100, 0.1) : si.smoo;
smoothing = hslider("h:[1]Filters/[1]smoothing", 1, 1, 10, 0.1);
rootNote = hslider("h:[1]Filters/[2]root (MIDI)", 45, 24, 72, 1);

// Filter intervals (semitones from each voice's note)
fInt1 = hslider("h:[1]Filters/[3]interval 1", 0, -12, 24, 1);
fInt2 = hslider("h:[1]Filters/[4]interval 2", 3, -12, 24, 1);
fInt3 = hslider("h:[1]Filters/[5]interval 3", 7, -12, 24, 1);
fInt4 = hslider("h:[1]Filters/[6]interval 4", 10, -12, 24, 1);

// Random frequency offset (cents, applied differently to each filter)
freqSpread = hslider("h:[1]Filters/[7]freq spread", 0, 0, 100, 1);

// Voice notes (MIDI, relative to root)
voice1Note = hslider("h:[2]Voices/[0]voice 1", 0, -24, 24, 1);
voice2Note = hslider("h:[2]Voices/[1]voice 2", 3, -24, 24, 1);
voice3Note = hslider("h:[2]Voices/[2]voice 3", 7, -24, 24, 1);
voice4Note = hslider("h:[2]Voices/[3]voice 4", 10, -24, 24, 1);
voice5Note = hslider("h:[2]Voices/[4]voice 5", 12, -24, 24, 1);
voice6Note = hslider("h:[2]Voices/[5]voice 6", 15, -24, 24, 1);
voice7Note = hslider("h:[2]Voices/[6]voice 7", 19, -24, 24, 1);
voice8Note = hslider("h:[2]Voices/[7]voice 8", 22, -24, 24, 1);

// Mix
singleGain = hslider("h:[3]Mix/[0]gain", 1.0, 0, 5, 0.01) : si.smoo;
coupling = hslider("h:[3]Mix/[1]coupling", 0.2, 0, 1, 0.01) : si.smoo;
distMode = nentry("h:[3]Mix/[2]distortion", 2, 0, 4, 1);
outputGain = hslider("h:[3]Mix/[3]output gain", 1.0, 0.1, 10, 0.1) : si.smoo;

// Parameter drift - adds slow random motion to all parameters
driftAmount = hslider("h:[3]Mix/[4]param drift", 0.0, 0, 1, 0.01);

//==============================================================================
// SMOOTH RANDOM DRIFT GENERATORS
// Creates slow, wandering modulation for organic feel
//==============================================================================

// Slow random generator using filtered noise
// rate controls speed (lower = slower), returns -1 to 1
slowRandom(seed, rate) = no.noise : *(seed * 0.0001 + 0.1) : fi.lowpass(1, rate) : *(10);

// Individual drift signals for each parameter (different seeds, very slow)
driftGamma = slowRandom(7919, 0.3) * driftAmount * 0.1;
driftOmega = slowRandom(1571, 0.25) * driftAmount * 0.5;
driftC = slowRandom(3571, 0.35) * driftAmount * 0.05;
driftDt = slowRandom(5381, 0.2) * driftAmount * 0.3;
driftQ = slowRandom(9973, 0.4) * driftAmount * 5;
driftCoupling = slowRandom(2749, 0.28) * driftAmount * 0.05;

// Apply drift to parameters
gammaWithDrift = gamma + driftGamma;
omegaWithDrift = omega + driftOmega;
cWithDrift = cBase + driftC;
dtWithDrift = dt + driftDt;
filterQWithDrift = filterQ + driftQ;
couplingWithDrift = coupling + driftCoupling;

//==============================================================================
// HELPERS
//==============================================================================

mtof(note) = 440 * pow(2, (note - 69) / 12);

// Distortion functions (from SC version)
hardClip(x) = max(-1, min(1, x));
varClip(x) = x / (1 + abs(x) * 3);
atanDist(x) = atan(x);
atanApprox(x) = 0.75 * (sqrt((x*1.3)*(x*1.3) + 1) * 1.65 - 1.65) / (x + 0.0001);
tanhApprox(x) = (0.1076*x*x*x + 3.029*x) / (x*x + 3.124);

distortion(mode, x) = ba.selectn(5, mode,
    hardClip(x), varClip(x), atanDist(x), atanApprox(x), tanhApprox(x));

dcblock = fi.dcblocker;

// Panning: pan = 0 (left) to 1 (right)
panner(pan) = _ <: (*(1-pan), *(pan));

//==============================================================================
// BIQUAD BANDPASS FILTER (matching SC implementation)
//==============================================================================

biquadBP(freq, Q) = fi.tf2(a0, a1, a2, b1, b2)
with {
    Fs = ma.SR;
    K = tan(ma.PI * freq / Fs);
    K2 = K * K;
    norm = 1.0 / (1.0 + K / Q + K2);
    a0 = K / Q * norm;
    a1 = 0.0;
    a2 = -a0;
    b1 = 2.0 * (K2 - 1.0) * norm;
    b2 = (1.0 - K / Q + K2) * norm;
};

//==============================================================================
// 8 VOICES - Different root notes for each (controlled by sliders)
//==============================================================================

// Voice notes from sliders (rootNote + voiceNNote offset)
voiceNote(0) = rootNote + voice1Note;
voiceNote(1) = rootNote + voice2Note;
voiceNote(2) = rootNote + voice3Note;
voiceNote(3) = rootNote + voice4Note;
voiceNote(4) = rootNote + voice5Note;
voiceNote(5) = rootNote + voice6Note;
voiceNote(6) = rootNote + voice7Note;
voiceNote(7) = rootNote + voice8Note;

// Panning per voice (0=left, 1=right)
voicePan(0) = 0.0;   // full left
voicePan(1) = 1.0;   // full right
voicePan(2) = 0.2;   // quite a bit left
voicePan(3) = 0.8;   // quite a bit right
voicePan(4) = 0.35;  // a bit left
voicePan(5) = 0.65;  // a bit right
voicePan(6) = 0.5;   // center
voicePan(7) = 0.5;   // center

// Pseudo-random offset per filter (deterministic based on voice and filter index)
// Returns value in cents based on freqSpread parameter
spreadOffset(voiceIdx, filterIdx) = freqSpread * offset / 100
with {
    // Simple deterministic "random" based on indices
    seed = (voiceIdx * 4 + filterIdx) * 7919;  // prime number for variety
    offset = ma.frac(seed * 0.61803398875) * 2 - 1;  // golden ratio for good distribution, range -1 to 1
};

// Convert cents offset to frequency multiplier
centsToRatio(cents) = pow(2, cents / 1200);

// Filter bank for voice n (4 filters with configurable intervals and spread)
filterBank(n) = _ <: (
    biquadBP(mtof(voiceNote(n) + fInt1) * centsToRatio(spreadOffset(n, 0)), filterQWithDrift),
    biquadBP(mtof(voiceNote(n) + fInt2) * centsToRatio(spreadOffset(n, 1)), filterQWithDrift),
    biquadBP(mtof(voiceNote(n) + fInt3) * centsToRatio(spreadOffset(n, 2)), filterQWithDrift),
    biquadBP(mtof(voiceNote(n) + fInt4) * centsToRatio(spreadOffset(n, 3)), filterQWithDrift)
) :> _;

//==============================================================================
// 8 COUPLED DUFFING OSCILLATORS
// c (damping) is modulated by the mix output
//==============================================================================

// Omega multipliers for each voice (slight detuning like original Max patch)
omegaMult(0) = 1.0;
omegaMult(1) = 1.007;
omegaMult(2) = 0.993;
omegaMult(3) = 1.015;
omegaMult(4) = 0.985;
omegaMult(5) = 1.023;
omegaMult(6) = 0.977;
omegaMult(7) = 1.031;

//==============================================================================
// 8-VOICE COUPLED SYSTEM
// State: 8 voices × 3 vars (duffX, duffY, t) = 24 state variables
// Plus 1 feedback for c modulation = 25 inputs
// Outputs: 16 audio (8 stereo pairs) + 24 state + 1 mix = 41 signals
//==============================================================================

eightVoiceSystem(
    x1, y1, t1,  x2, y2, t2,  x3, y3, t3,  x4, y4, t4,
    x5, y5, t5,  x6, y6, t6,  x7, y7, t7,  x8, y8, t8,
    mixFeedback
) =
    outL1, outR1, x1n, y1n, t1n,  outL2, outR2, x2n, y2n, t2n,
    outL3, outR3, x3n, y3n, t3n,  outL4, outR4, x4n, y4n, t4n,
    outL5, outR5, x5n, y5n, t5n,  outL6, outR6, x6n, y6n, t6n,
    outL7, outR7, x7n, y7n, t7n,  outL8, outR8, x8n, y8n, t8n,
    mixOut
with {
    // Sum of all duffX for coupling
    xSum = x1 + x2 + x3 + x4 + x5 + x6 + x7 + x8;

    // c (damping) modulated by mix feedback + drift
    cModulated = cWithDrift + (mixFeedback * cMod);

    // Voice 1 (D, full left)
    t1n = t1 + dtWithDrift;
    fY1 = x1 : filterBank(0) : *(singleGain);
    coup1 = (xSum - x1) * couplingWithDrift / 7;
    forcing1 = gammaWithDrift * sin(omegaWithDrift * omegaMult(0) * t1n) + coup1;
    dy1 = fY1 - (fY1*fY1*fY1) - (cModulated * y1) + forcing1;
    y1n = y1 + dy1;
    x1lp = x1 + (fY1 + y1n - x1) / smoothing;
    x1n = distortion(distMode, x1lp);
    outL1 = fY1 * (1 - voicePan(0));
    outR1 = fY1 * voicePan(0);

    // Voice 2 (G#, full right)
    t2n = t2 + dtWithDrift;
    fY2 = x2 : filterBank(1) : *(singleGain);
    coup2 = (xSum - x2) * couplingWithDrift / 7;
    forcing2 = gammaWithDrift * sin(omegaWithDrift * omegaMult(1) * t2n) + coup2;
    dy2 = fY2 - (fY2*fY2*fY2) - (cModulated * y2) + forcing2;
    y2n = y2 + dy2;
    x2lp = x2 + (fY2 + y2n - x2) / smoothing;
    x2n = distortion(distMode, x2lp);
    outL2 = fY2 * (1 - voicePan(1));
    outR2 = fY2 * voicePan(1);

    // Voice 3 (B, quite left)
    t3n = t3 + dtWithDrift;
    fY3 = x3 : filterBank(2) : *(singleGain);
    coup3 = (xSum - x3) * couplingWithDrift / 7;
    forcing3 = gammaWithDrift * sin(omegaWithDrift * omegaMult(2) * t3n) + coup3;
    dy3 = fY3 - (fY3*fY3*fY3) - (cModulated * y3) + forcing3;
    y3n = y3 + dy3;
    x3lp = x3 + (fY3 + y3n - x3) / smoothing;
    x3n = distortion(distMode, x3lp);
    outL3 = fY3 * (1 - voicePan(2));
    outR3 = fY3 * voicePan(2);

    // Voice 4 (A, quite right)
    t4n = t4 + dtWithDrift;
    fY4 = x4 : filterBank(3) : *(singleGain);
    coup4 = (xSum - x4) * couplingWithDrift / 7;
    forcing4 = gammaWithDrift * sin(omegaWithDrift * omegaMult(3) * t4n) + coup4;
    dy4 = fY4 - (fY4*fY4*fY4) - (cModulated * y4) + forcing4;
    y4n = y4 + dy4;
    x4lp = x4 + (fY4 + y4n - x4) / smoothing;
    x4n = distortion(distMode, x4lp);
    outL4 = fY4 * (1 - voicePan(3));
    outR4 = fY4 * voicePan(3);

    // Voice 5 (B, bit left)
    t5n = t5 + dtWithDrift;
    fY5 = x5 : filterBank(4) : *(singleGain);
    coup5 = (xSum - x5) * couplingWithDrift / 7;
    forcing5 = gammaWithDrift * sin(omegaWithDrift * omegaMult(4) * t5n) + coup5;
    dy5 = fY5 - (fY5*fY5*fY5) - (cModulated * y5) + forcing5;
    y5n = y5 + dy5;
    x5lp = x5 + (fY5 + y5n - x5) / smoothing;
    x5n = distortion(distMode, x5lp);
    outL5 = fY5 * (1 - voicePan(4));
    outR5 = fY5 * voicePan(4);

    // Voice 6 (A, bit right)
    t6n = t6 + dtWithDrift;
    fY6 = x6 : filterBank(5) : *(singleGain);
    coup6 = (xSum - x6) * couplingWithDrift / 7;
    forcing6 = gammaWithDrift * sin(omegaWithDrift * omegaMult(5) * t6n) + coup6;
    dy6 = fY6 - (fY6*fY6*fY6) - (cModulated * y6) + forcing6;
    y6n = y6 + dy6;
    x6lp = x6 + (fY6 + y6n - x6) / smoothing;
    x6n = distortion(distMode, x6lp);
    outL6 = fY6 * (1 - voicePan(5));
    outR6 = fY6 * voicePan(5);

    // Voice 7 (B, center)
    t7n = t7 + dtWithDrift;
    fY7 = x7 : filterBank(6) : *(singleGain);
    coup7 = (xSum - x7) * couplingWithDrift / 7;
    forcing7 = gammaWithDrift * sin(omegaWithDrift * omegaMult(6) * t7n) + coup7;
    dy7 = fY7 - (fY7*fY7*fY7) - (cModulated * y7) + forcing7;
    y7n = y7 + dy7;
    x7lp = x7 + (fY7 + y7n - x7) / smoothing;
    x7n = distortion(distMode, x7lp);
    outL7 = fY7 * (1 - voicePan(6));
    outR7 = fY7 * voicePan(6);

    // Voice 8 (A, center)
    t8n = t8 + dtWithDrift;
    fY8 = x8 : filterBank(7) : *(singleGain);
    coup8 = (xSum - x8) * couplingWithDrift / 7;
    forcing8 = gammaWithDrift * sin(omegaWithDrift * omegaMult(7) * t8n) + coup8;
    dy8 = fY8 - (fY8*fY8*fY8) - (cModulated * y8) + forcing8;
    y8n = y8 + dy8;
    x8lp = x8 + (fY8 + y8n - x8) / smoothing;
    x8n = distortion(distMode, x8lp);
    outL8 = fY8 * (1 - voicePan(7));
    outR8 = fY8 * voicePan(7);

    // Mix output for c modulation feedback
    mixOut = (fY1 + fY2 + fY3 + fY4 + fY5 + fY6 + fY7 + fY8) * 0.125;
};

// Feedback: extract state vars + mix for c modulation
eightVoiceFeedback(
    oL1, oR1, x1, y1, t1,  oL2, oR2, x2, y2, t2,
    oL3, oR3, x3, y3, t3,  oL4, oR4, x4, y4, t4,
    oL5, oR5, x5, y5, t5,  oL6, oR6, x6, y6, t6,
    oL7, oR7, x7, y7, t7,  oL8, oR8, x8, y8, t8,
    mix
) = x1, y1, t1,  x2, y2, t2,  x3, y3, t3,  x4, y4, t4,
    x5, y5, t5,  x6, y6, t6,  x7, y7, t7,  x8, y8, t8,
    mix;

//==============================================================================
// MAIN PROCESS
//==============================================================================

// Sum stereo pairs into L/R outputs with output gain
sumStereo(l1,r1,l2,r2,l3,r3,l4,r4,l5,r5,l6,r6,l7,r7,l8,r8) =
    ((l1+l2+l3+l4+l5+l6+l7+l8) * 0.125 : dcblock : *(outputGain)),
    ((r1+r2+r3+r4+r5+r6+r7+r8) * 0.125 : dcblock : *(outputGain));

process = (eightVoiceSystem ~ eightVoiceFeedback) :
    // Keep stereo outputs, discard state vars and mix
    // Pattern: L, R, x, y, t repeated 8 times, then mix
    (_, _, !, !, !,  _, _, !, !, !,  _, _, !, !, !,  _, _, !, !, !,
     _, _, !, !, !,  _, _, !, !, !,  _, _, !, !, !,  _, _, !, !, !, !) :
    // Sum all 8 stereo pairs into final L/R
    sumStereo;
