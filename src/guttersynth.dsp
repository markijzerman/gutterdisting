// Guttersynth NT - 4 Coupled Duffing Oscillators (Disting NT optimized)
// Based on Tom Mudd's Guttersynth
// Port by M. IJzerman
//
// NT-optimized: 4 voices × 8 filters = 32 biquads
// No parameter drift for CPU savings

declare guid "GutS";
declare name "Gutter Synth NT";
declare description "4 coupled Duffing oscillators with filter banks";

import("stdfaust.lib");

//==============================================================================
// PARAMETERS
//==============================================================================

// Duffing oscillator parameters
gamma = hslider("h:[0]Duffing/[0]gamma", 0.1, 0, 5, 0.001) : si.smoo;
omega = hslider("h:[0]Duffing/[1]omega", 1.25, 0.1, 10, 0.01) : si.smoo;
c = hslider("h:[0]Duffing/[2]c (damping)", 0.3, 0, 1, 0.001) : si.smoo;
dt = hslider("h:[0]Duffing/[3]dt", 1, 0.001, 10, 0.001) : si.smoo;
cMod = hslider("h:[0]Duffing/[4]c modulation", 0.0, 0, 1, 0.01) : si.smoo;

// Filter parameters
filterQ = hslider("h:[1]Filters/[0]Q", 30, 0.5, 100, 0.1) : si.smoo;
smoothing = hslider("h:[1]Filters/[1]smoothing", 1, 1, 10, 0.1);

// Filter preset selector (0-7) - 8 key presets from filters.txt
// 0=Standard, 1=Cluster, 2=Dense, 3=Growl, 4=Harmonic, 5=High, 6=Wide, 7=Clustered
filterPreset = nentry("h:[1]Filters/[2]filter preset", 3, 0, 7, 1);

// Voice root notes (semitones offset from base preset)
voice1Root = hslider("h:[1]Filters/[3]voice 1 root", 0, -24, 48, 1);
voice2Root = hslider("h:[1]Filters/[4]voice 2 root", 12, -24, 48, 1);
voice3Root = hslider("h:[1]Filters/[5]voice 3 root", 24, -24, 48, 1);
voice4Root = hslider("h:[1]Filters/[6]voice 4 root", 36, -24, 48, 1);

// Voice volumes
voice1Vol = hslider("h:[1]Filters/[7]voice 1 vol", 1.0, 0, 2, 0.01) : si.smoo;
voice2Vol = hslider("h:[1]Filters/[8]voice 2 vol", 1.0, 0, 2, 0.01) : si.smoo;
voice3Vol = hslider("h:[1]Filters/[9]voice 3 vol", 1.0, 0, 2, 0.01) : si.smoo;
voice4Vol = hslider("h:[1]Filters/[10]voice 4 vol", 1.0, 0, 2, 0.01) : si.smoo;

// Mix
singleGain = hslider("h:[2]Mix/[0]gain", 1.0, 0, 5, 0.01) : si.smoo;
coupling = hslider("h:[2]Mix/[1]coupling", 0.2, 0, 1, 0.01) : si.smoo;
distMode = nentry("h:[2]Mix/[2]distortion", 2, 0, 4, 1);
outputGain = hslider("h:[2]Mix/[3]output gain", 1.0, 0.1, 10, 0.1) : si.smoo;

// External audio input mix (0 = internal sine only, 1 = external audio only)
extAudioMix = hslider("h:[2]Mix/[4]ext audio mix", 0.0, 0, 1, 0.01) : si.smoo;
extAudioGain = hslider("h:[2]Mix/[5]ext audio gain", 1.0, 0, 10, 0.1) : si.smoo;

//==============================================================================
// HELPERS
//==============================================================================

// Simple safety clamp for state variables
clamp100(x) = max(-100, min(100, x));

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
// FILTER PRESETS (8 key presets from filters.txt)
// Each preset has 8 representative frequencies in Hz
//==============================================================================

// Preset 0: Standard - mid-range spread (from line 0 of filters.txt)
p0f(0) = 97;   p0f(1) = 156;  p0f(2) = 200;  p0f(3) = 318;
p0f(4) = 435;  p0f(5) = 500;  p0f(6) = 678;  p0f(7) = 883;

// Preset 1: Cluster (from line 4 of filters.txt)
p1f(0) = 141;  p1f(1) = 222;  p1f(2) = 298;  p1f(3) = 552;
p1f(4) = 758;  p1f(5) = 1041; p1f(6) = 1345; p1f(7) = 1578;

// Preset 2: Dense (from line 5 of filters.txt)
p2f(0) = 68;   p2f(1) = 170;  p2f(2) = 248;  p2f(3) = 449;
p2f(4) = 589;  p2f(5) = 771;  p2f(6) = 879;  p2f(7) = 1053;

// Preset 3: Growl - very low (from line 7 of filters.txt)
p3f(0) = 30;   p3f(1) = 60;   p3f(2) = 90;   p3f(3) = 166;
p3f(4) = 270;  p3f(5) = 308;  p3f(6) = 490;  p3f(7) = 953;

// Preset 4: Harmonic (from line 8 of filters.txt)
p4f(0) = 64;   p4f(1) = 98;   p4f(2) = 130;  p4f(3) = 196;
p4f(4) = 227;  p4f(5) = 294;  p4f(6) = 360;  p4f(7) = 426;

// Preset 5: High frequencies (from line 9 of filters.txt)
p5f(0) = 338;  p5f(1) = 875;  p5f(2) = 1050; p5f(3) = 1620;
p5f(4) = 1852; p5f(5) = 2243; p5f(6) = 2584; p5f(7) = 2893;

// Preset 6: Wide range (from line 14 of filters.txt)
p6f(0) = 128;  p6f(1) = 267;  p6f(2) = 315;  p6f(3) = 398;
p6f(4) = 531;  p6f(5) = 631;  p6f(6) = 800;  p6f(7) = 944;

// Preset 7: Clustered mid (from line 10 of filters.txt)
p7f(0) = 387;  p7f(1) = 392;  p7f(2) = 408;  p7f(3) = 612;
p7f(4) = 625;  p7f(5) = 640;  p7f(6) = 653;  p7f(7) = 665;

// Convert semitones to frequency multiplier
semitonesToRatio(semi) = pow(2, semi / 12);

// Voice frequency multiplier from root note sliders
voiceFreqMult(0) = semitonesToRatio(voice1Root);
voiceFreqMult(1) = semitonesToRatio(voice2Root);
voiceFreqMult(2) = semitonesToRatio(voice3Root);
voiceFreqMult(3) = semitonesToRatio(voice4Root);

// Get frequency for preset and filter index (8 presets)
presetFreq(preset, idx) = ba.selectn(8, preset,
    p0f(idx), p1f(idx), p2f(idx), p3f(idx),
    p4f(idx), p5f(idx), p6f(idx), p7f(idx));

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

// Filter bank for voice n (8 filters)
filterBank(n) = _ <: (
    biquadBP(getFilterFreq(n, 0), filterQ),
    biquadBP(getFilterFreq(n, 1), filterQ),
    biquadBP(getFilterFreq(n, 2), filterQ),
    biquadBP(getFilterFreq(n, 3), filterQ),
    biquadBP(getFilterFreq(n, 4), filterQ),
    biquadBP(getFilterFreq(n, 5), filterQ),
    biquadBP(getFilterFreq(n, 6), filterQ),
    biquadBP(getFilterFreq(n, 7), filterQ)
) :> _;

// Omega multipliers for each voice (slight detuning)
omegaMult(0) = 1.0;
omegaMult(1) = 1.007;
omegaMult(2) = 0.993;
omegaMult(3) = 1.015;

//==============================================================================
// 4-VOICE COUPLED SYSTEM WITH AUDIO INPUT
// audioIn: mono external audio (passed as first arg, not in feedback loop)
// State: 4 voices × 3 vars (duffX, duffY, t) = 12 state variables
// Plus 1 feedback for c modulation = 13 feedback inputs
// Outputs: 8 audio (4 stereo pairs) + 12 state + 1 mix = 21 signals
//==============================================================================

fourVoiceSystem(audioIn,
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

    // External audio scaled
    extAudio = audioIn * extAudioGain;

    // Voice 1 (full left)
    t1n = t1 + dt;
    fY1 = (x1 : filterBank(0)) * singleGain;
    coup1 = (xSum - x1) * coupling / 3;
    internalOsc1 = sin(omega * omegaMult(0) * t1n);
    forcingOsc1 = internalOsc1 * (1 - extAudioMix) + extAudio * extAudioMix;
    forcing1 = gamma * forcingOsc1 + coup1;
    dy1 = fY1 - (fY1*fY1*fY1) - (cModulated * y1) + forcing1;
    y1n = clamp100(y1 + dy1);
    x1lp = x1 + (fY1 + y1n - x1) / smoothing;
    x1n = distortion(distMode, x1lp);
    outL1 = fY1 * (1 - voicePan(0)) * voice1Vol;
    outR1 = fY1 * voicePan(0) * voice1Vol;

    // Voice 2 (full right)
    t2n = t2 + dt;
    fY2 = (x2 : filterBank(1)) * singleGain;
    coup2 = (xSum - x2) * coupling / 3;
    internalOsc2 = sin(omega * omegaMult(1) * t2n);
    forcingOsc2 = internalOsc2 * (1 - extAudioMix) + extAudio * extAudioMix;
    forcing2 = gamma * forcingOsc2 + coup2;
    dy2 = fY2 - (fY2*fY2*fY2) - (cModulated * y2) + forcing2;
    y2n = clamp100(y2 + dy2);
    x2lp = x2 + (fY2 + y2n - x2) / smoothing;
    x2n = distortion(distMode, x2lp);
    outL2 = fY2 * (1 - voicePan(1)) * voice2Vol;
    outR2 = fY2 * voicePan(1) * voice2Vol;

    // Voice 3 (left-ish)
    t3n = t3 + dt;
    fY3 = (x3 : filterBank(2)) * singleGain;
    coup3 = (xSum - x3) * coupling / 3;
    internalOsc3 = sin(omega * omegaMult(2) * t3n);
    forcingOsc3 = internalOsc3 * (1 - extAudioMix) + extAudio * extAudioMix;
    forcing3 = gamma * forcingOsc3 + coup3;
    dy3 = fY3 - (fY3*fY3*fY3) - (cModulated * y3) + forcing3;
    y3n = clamp100(y3 + dy3);
    x3lp = x3 + (fY3 + y3n - x3) / smoothing;
    x3n = distortion(distMode, x3lp);
    outL3 = fY3 * (1 - voicePan(2)) * voice3Vol;
    outR3 = fY3 * voicePan(2) * voice3Vol;

    // Voice 4 (right-ish)
    t4n = t4 + dt;
    fY4 = (x4 : filterBank(3)) * singleGain;
    coup4 = (xSum - x4) * coupling / 3;
    internalOsc4 = sin(omega * omegaMult(3) * t4n);
    forcingOsc4 = internalOsc4 * (1 - extAudioMix) + extAudio * extAudioMix;
    forcing4 = gamma * forcingOsc4 + coup4;
    dy4 = fY4 - (fY4*fY4*fY4) - (cModulated * y4) + forcing4;
    y4n = clamp100(y4 + dy4);
    x4lp = x4 + (fY4 + y4n - x4) / smoothing;
    x4n = distortion(distMode, x4lp);
    outL4 = fY4 * (1 - voicePan(3)) * voice4Vol;
    outR4 = fY4 * voicePan(3) * voice4Vol;

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

// Process with stereo audio input
// Input: L, R stereo audio
// Output: L, R stereo audio
//
// When extAudioMix = 0: pure internal sine oscillator (original synth behavior)
// When extAudioMix = 1: external audio drives the forcing function
// Values in between blend the two sources
processWithInput(inL, inR) = (fourVoiceSystem(audioMono) ~ fourVoiceFeedback) :
    // Keep stereo outputs, discard state vars and mix
    (_, _, !, !, !,  _, _, !, !, !,  _, _, !, !, !,  _, _, !, !, !, !) :
    sumStereo
with {
    // Sum stereo to mono for forcing function
    audioMono = (inL + inR) * 0.5;
};

// Main process: stereo in, stereo out
process = _, _ : processWithInput;
