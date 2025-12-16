// Guttersynth NT - 4 Coupled Duffing Oscillators (Disting NT optimized)
// Based on Tom Mudd's Guttersynth
// Port by M. IJzerman
//
// NT-optimized: 4 voices × 4 filters = 16 biquads (vs 64 in full version)
// No parameter drift for CPU savings

declare guid "GutS";
declare name "Gutter Synth NT";
declare description "4 coupled Duffing oscillators with filter banks";

import("stdfaust.lib");

//==============================================================================
// PARAMETERS
//==============================================================================

// Duffing oscillator parameters
gamma = hslider("h:[0]Duffing/[0]gamma", 0.1, 0, 2, 0.001) : si.smoo;
omega = hslider("h:[0]Duffing/[1]omega", 1.25, 0.1, 10, 0.01) : si.smoo;
c = hslider("h:[0]Duffing/[2]c (damping)", 0.3, 0, 1, 0.001) : si.smoo;
dt = hslider("h:[0]Duffing/[3]dt", 1, 0.001, 10, 0.001) : si.smoo;
cMod = hslider("h:[0]Duffing/[4]c modulation", 0.0, 0, 1, 0.01) : si.smoo;

// Filter parameters
filterQ = hslider("h:[1]Filters/[0]Q", 30, 0.5, 100, 0.1) : si.smoo;
smoothing = hslider("h:[1]Filters/[1]smoothing", 1, 1, 10, 0.1);

// Filter preset selector (0-3)
// 0 = Growling (30-166 Hz), 1 = Harmonic (64-196 Hz), 2 = Dense (68-391 Hz), 3 = Standard (97-318 Hz)
filterPreset = nentry("h:[1]Filters/[2]filter preset", 0, 0, 3, 1);

// Voice root notes (semitones offset from base preset)
voice1Root = hslider("h:[1]Filters/[3]voice 1 root", 0, -24, 48, 1);
voice2Root = hslider("h:[1]Filters/[4]voice 2 root", 12, -24, 48, 1);
voice3Root = hslider("h:[1]Filters/[5]voice 3 root", 24, -24, 48, 1);
voice4Root = hslider("h:[1]Filters/[6]voice 4 root", 36, -24, 48, 1);

// Mix
singleGain = hslider("h:[2]Mix/[0]gain", 1.0, 0, 5, 0.01) : si.smoo;
coupling = hslider("h:[2]Mix/[1]coupling", 0.2, 0, 1, 0.01) : si.smoo;
distMode = nentry("h:[2]Mix/[2]distortion", 2, 0, 4, 1);
outputGain = hslider("h:[2]Mix/[3]output gain", 1.0, 0.1, 10, 0.1) : si.smoo;

//==============================================================================
// HELPERS
//==============================================================================

// Distortion functions
hardClip(x) = max(-1, min(1, x));
varClip(x) = x / (1 + abs(x) * 3);
atanDist(x) = atan(x);
atanApprox(x) = 0.75 * (sqrt((x*1.3)*(x*1.3) + 1) * 1.65 - 1.65) / (x + 0.0001);
tanhApprox(x) = (0.1076*x*x*x + 3.029*x) / (x*x + 3.124);

distortion(mode, x) = ba.selectn(5, mode,
    hardClip(x), varClip(x), atanDist(x), atanApprox(x), tanhApprox(x));

dcblock = fi.dcblocker;

//==============================================================================
// FILTER PRESETS (from original filters.txt)
// Each preset has 4 frequencies in Hz
//==============================================================================

// Preset 0: Growling - very low fundamentals
growlFreq(0) = 30;   growlFreq(1) = 60;   growlFreq(2) = 90;   growlFreq(3) = 166;

// Preset 1: Harmonic - evenly spaced for organ-like tones
harmFreq(0) = 64;   harmFreq(1) = 98;   harmFreq(2) = 130;  harmFreq(3) = 196;

// Preset 2: Dense - many close frequencies
denseFreq(0) = 68;   denseFreq(1) = 97;   denseFreq(2) = 170;  denseFreq(3) = 391;

// Preset 3: Standard - mid-range spread
stdFreq(0) = 97;   stdFreq(1) = 156;  stdFreq(2) = 200;  stdFreq(3) = 318;

// Convert semitones to frequency multiplier
semitonesToRatio(semi) = pow(2, semi / 12);

// Voice frequency multiplier from root note sliders
voiceFreqMult(0) = semitonesToRatio(voice1Root);
voiceFreqMult(1) = semitonesToRatio(voice2Root);
voiceFreqMult(2) = semitonesToRatio(voice3Root);
voiceFreqMult(3) = semitonesToRatio(voice4Root);

// Get frequency for preset and filter index
presetFreq(preset, idx) = ba.selectn(4, preset,
    growlFreq(idx), harmFreq(idx), denseFreq(idx), stdFreq(idx));

// Get filter frequency for voice n, filter index i
getFilterFreq(n, i) = presetFreq(filterPreset, i) * voiceFreqMult(n);

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
// 4 VOICES
//==============================================================================

// Panning per voice (0=left, 1=right)
voicePan(0) = 0.0;   // full left
voicePan(1) = 1.0;   // full right
voicePan(2) = 0.3;   // left-ish
voicePan(3) = 0.7;   // right-ish

// Filter bank for voice n (4 filters)
filterBank(n) = _ <: (
    biquadBP(getFilterFreq(n, 0), filterQ),
    biquadBP(getFilterFreq(n, 1), filterQ),
    biquadBP(getFilterFreq(n, 2), filterQ),
    biquadBP(getFilterFreq(n, 3), filterQ)
) :> _;

// Omega multipliers for each voice (slight detuning)
omegaMult(0) = 1.0;
omegaMult(1) = 1.007;
omegaMult(2) = 0.993;
omegaMult(3) = 1.015;

//==============================================================================
// 4-VOICE COUPLED SYSTEM
// State: 4 voices × 3 vars (duffX, duffY, t) = 12 state variables
// Plus 1 feedback for c modulation = 13 inputs
// Outputs: 8 audio (4 stereo pairs) + 12 state + 1 mix = 21 signals
//==============================================================================

fourVoiceSystem(
    x1, y1, t1,  x2, y2, t2,  x3, y3, t3,  x4, y4, t4,
    mixFeedback
) =
    outL1, outR1, x1n, y1n, t1n,  outL2, outR2, x2n, y2n, t2n,
    outL3, outR3, x3n, y3n, t3n,  outL4, outR4, x4n, y4n, t4n,
    mixOut
with {
    // Sum of all duffX for coupling
    xSum = x1 + x2 + x3 + x4;

    // c (damping) modulated by mix feedback
    cModulated = c + (mixFeedback * cMod);

    // Voice 1 (full left)
    t1n = t1 + dt;
    fY1 = x1 : filterBank(0) : *(singleGain);
    coup1 = (xSum - x1) * coupling / 3;
    forcing1 = gamma * sin(omega * omegaMult(0) * t1n) + coup1;
    dy1 = fY1 - (fY1*fY1*fY1) - (cModulated * y1) + forcing1;
    y1n = y1 + dy1;
    x1lp = x1 + (fY1 + y1n - x1) / smoothing;
    x1n = distortion(distMode, x1lp);
    outL1 = fY1 * (1 - voicePan(0));
    outR1 = fY1 * voicePan(0);

    // Voice 2 (full right)
    t2n = t2 + dt;
    fY2 = x2 : filterBank(1) : *(singleGain);
    coup2 = (xSum - x2) * coupling / 3;
    forcing2 = gamma * sin(omega * omegaMult(1) * t2n) + coup2;
    dy2 = fY2 - (fY2*fY2*fY2) - (cModulated * y2) + forcing2;
    y2n = y2 + dy2;
    x2lp = x2 + (fY2 + y2n - x2) / smoothing;
    x2n = distortion(distMode, x2lp);
    outL2 = fY2 * (1 - voicePan(1));
    outR2 = fY2 * voicePan(1);

    // Voice 3 (left-ish)
    t3n = t3 + dt;
    fY3 = x3 : filterBank(2) : *(singleGain);
    coup3 = (xSum - x3) * coupling / 3;
    forcing3 = gamma * sin(omega * omegaMult(2) * t3n) + coup3;
    dy3 = fY3 - (fY3*fY3*fY3) - (cModulated * y3) + forcing3;
    y3n = y3 + dy3;
    x3lp = x3 + (fY3 + y3n - x3) / smoothing;
    x3n = distortion(distMode, x3lp);
    outL3 = fY3 * (1 - voicePan(2));
    outR3 = fY3 * voicePan(2);

    // Voice 4 (right-ish)
    t4n = t4 + dt;
    fY4 = x4 : filterBank(3) : *(singleGain);
    coup4 = (xSum - x4) * coupling / 3;
    forcing4 = gamma * sin(omega * omegaMult(3) * t4n) + coup4;
    dy4 = fY4 - (fY4*fY4*fY4) - (cModulated * y4) + forcing4;
    y4n = y4 + dy4;
    x4lp = x4 + (fY4 + y4n - x4) / smoothing;
    x4n = distortion(distMode, x4lp);
    outL4 = fY4 * (1 - voicePan(3));
    outR4 = fY4 * voicePan(3);

    // Mix output for c modulation feedback
    mixOut = (fY1 + fY2 + fY3 + fY4) * 0.25;
};

// Feedback: extract state vars + mix for c modulation
fourVoiceFeedback(
    oL1, oR1, x1, y1, t1,  oL2, oR2, x2, y2, t2,
    oL3, oR3, x3, y3, t3,  oL4, oR4, x4, y4, t4,
    mix
) = x1, y1, t1,  x2, y2, t2,  x3, y3, t3,  x4, y4, t4,  mix;

//==============================================================================
// MAIN PROCESS
//==============================================================================

// Sum stereo pairs into L/R outputs
sumStereo(l1,r1,l2,r2,l3,r3,l4,r4) =
    ((l1+l2+l3+l4) * 0.25 : dcblock : *(outputGain)),
    ((r1+r2+r3+r4) * 0.25 : dcblock : *(outputGain));

// Main process (no audio input for now - simpler and more stable)
// Outputs: L, R stereo audio
process = (fourVoiceSystem ~ fourVoiceFeedback) :
    // Keep stereo outputs, discard state vars and mix
    (_, _, !, !, !,  _, _, !, !, !,  _, _, !, !, !,  _, _, !, !, !, !) :
    sumStereo;
