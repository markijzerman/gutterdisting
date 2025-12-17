// Guttersynth NT - 8 Coupled Duffing Oscillators
// Based on Tom Mudd's Guttersynth
// Port by M. IJzerman
//
// 8 voices × 4 filters = 32 biquads (matching original voice count)

declare guid "Gut8";
declare name "Gutter 8-Voice";
declare description "8 coupled Duffing oscillators with filter banks";

import("stdfaust.lib");

//==============================================================================
// PARAMETERS
//==============================================================================

gamma = hslider("h:[0]Duffing/[0]gamma", 0.1, 0, 5, 0.001) : si.smoo;
omega = hslider("h:[0]Duffing/[1]omega", 1.25, 0.1, 10, 0.01) : si.smoo;
c = hslider("h:[0]Duffing/[2]c (damping)", 0.3, 0, 1, 0.001) : si.smoo;
dt = hslider("h:[0]Duffing/[3]dt", 1, 0.001, 10, 0.001) : si.smoo;
cMod = hslider("h:[0]Duffing/[4]c modulation", 0.0, 0, 1, 0.01) : si.smoo;

filterQ = hslider("h:[1]Filters/[0]Q", 30, 0.5, 100, 0.1) : si.smoo;
smoothing = hslider("h:[1]Filters/[1]smoothing", 1, 1, 10, 0.1);
filterPreset = nentry("h:[1]Filters/[2]filter preset", 3, 0, 7, 1);

voice1Root = hslider("h:[1]Filters/[3]v1 root", 0, -24, 48, 1);
voice2Root = hslider("h:[1]Filters/[4]v2 root", 7, -24, 48, 1);
voice3Root = hslider("h:[1]Filters/[5]v3 root", 12, -24, 48, 1);
voice4Root = hslider("h:[1]Filters/[6]v4 root", 19, -24, 48, 1);
voice5Root = hslider("h:[1]Filters/[7]v5 root", 24, -24, 48, 1);
voice6Root = hslider("h:[1]Filters/[8]v6 root", 31, -24, 48, 1);
voice7Root = hslider("h:[1]Filters/[9]v7 root", 36, -24, 48, 1);
voice8Root = hslider("h:[1]Filters/[10]v8 root", 43, -24, 48, 1);

singleGain = hslider("h:[2]Mix/[0]gain", 1.0, 0, 5, 0.01) : si.smoo;
coupling = hslider("h:[2]Mix/[1]coupling", 0.2, 0, 1, 0.01) : si.smoo;
distMode = nentry("h:[2]Mix/[2]distortion", 2, 0, 4, 1);
outputGain = hslider("h:[2]Mix/[3]output gain", 1.0, 0.1, 10, 0.1) : si.smoo;
extAudioMix = hslider("h:[2]Mix/[4]ext audio mix", 0.0, 0, 1, 0.01) : si.smoo;
extAudioGain = hslider("h:[2]Mix/[5]ext audio gain", 1.0, 0, 10, 0.1) : si.smoo;

//==============================================================================
// HELPERS
//==============================================================================

clamp100(x) = max(-100, min(100, x));
hardClip(x) = max(-1, min(1, x));
varClip(x) = x / (1 + abs(x) * 3);
atanDist(x) = atan(x);
atanApprox(x) = 0.75 * (sqrt((x*1.3)*(x*1.3) + 1) * 1.65 - 1.65) / (x + 0.0001);
tanhApprox(x) = (0.1076*x*x*x + 3.029*x) / (x*x + 3.124);
distortion(mode, x) = ba.selectn(5, mode,
    hardClip(x), varClip(x), atanDist(x), atanApprox(x), tanhApprox(x));
dcblock = fi.dcblocker;

//==============================================================================
// FILTER PRESETS
//==============================================================================

p0f(0) = 97;   p0f(1) = 200;  p0f(2) = 435;  p0f(3) = 720;
p1f(0) = 141;  p1f(1) = 298;  p1f(2) = 758;  p1f(3) = 1578;
p2f(0) = 68;   p2f(1) = 248;  p2f(2) = 589;  p2f(3) = 1053;
p3f(0) = 30;   p3f(1) = 60;   p3f(2) = 166;  p3f(3) = 490;
p4f(0) = 64;   p4f(1) = 130;  p4f(2) = 227;  p4f(3) = 393;
p5f(0) = 338;  p5f(1) = 1050; p5f(2) = 1852; p5f(3) = 2893;
p6f(0) = 128;  p6f(1) = 267;  p6f(2) = 531;  p6f(3) = 944;
p7f(0) = 387;  p7f(1) = 408;  p7f(2) = 625;  p7f(3) = 657;

semitonesToRatio(semi) = pow(2, semi / 12);
voiceFreqMult(0) = semitonesToRatio(voice1Root);
voiceFreqMult(1) = semitonesToRatio(voice2Root);
voiceFreqMult(2) = semitonesToRatio(voice3Root);
voiceFreqMult(3) = semitonesToRatio(voice4Root);
voiceFreqMult(4) = semitonesToRatio(voice5Root);
voiceFreqMult(5) = semitonesToRatio(voice6Root);
voiceFreqMult(6) = semitonesToRatio(voice7Root);
voiceFreqMult(7) = semitonesToRatio(voice8Root);

presetFreq(preset, idx) = ba.selectn(8, preset,
    p0f(idx), p1f(idx), p2f(idx), p3f(idx),
    p4f(idx), p5f(idx), p6f(idx), p7f(idx));
getFilterFreq(n, i) = presetFreq(filterPreset, i) * voiceFreqMult(n);

//==============================================================================
// BIQUAD & FILTER BANK
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

voicePan(0) = 0.0;   voicePan(1) = 1.0;
voicePan(2) = 0.15;  voicePan(3) = 0.85;
voicePan(4) = 0.3;   voicePan(5) = 0.7;
voicePan(6) = 0.45;  voicePan(7) = 0.55;

filterBank(n) = _ <: (
    biquadBP(getFilterFreq(n, 0), filterQ),
    biquadBP(getFilterFreq(n, 1), filterQ),
    biquadBP(getFilterFreq(n, 2), filterQ),
    biquadBP(getFilterFreq(n, 3), filterQ)
) :> _;

omegaMult(0) = 1.0;    omegaMult(1) = 1.007;
omegaMult(2) = 0.993;  omegaMult(3) = 1.015;
omegaMult(4) = 0.985;  omegaMult(5) = 1.022;
omegaMult(6) = 0.978;  omegaMult(7) = 1.030;

//==============================================================================
// 8-VOICE SYSTEM
//==============================================================================

eightVoiceSystem(audioIn,
    x1,y1,t1, x2,y2,t2, x3,y3,t3, x4,y4,t4,
    x5,y5,t5, x6,y6,t6, x7,y7,t7, x8,y8,t8,
    mixFB
) =
    oL1,oR1, x1n,y1n,t1n, oL2,oR2, x2n,y2n,t2n,
    oL3,oR3, x3n,y3n,t3n, oL4,oR4, x4n,y4n,t4n,
    oL5,oR5, x5n,y5n,t5n, oL6,oR6, x6n,y6n,t6n,
    oL7,oR7, x7n,y7n,t7n, oL8,oR8, x8n,y8n,t8n,
    mixOut
with {
    xSum = x1+x2+x3+x4+x5+x6+x7+x8;
    cMod2 = c + (mixFB * cMod);
    extAudio = audioIn * extAudioGain;

    // Voice 1
    t1n = t1 + dt;
    fY1 = (x1 : filterBank(0)) * singleGain;
    coup1 = (xSum - x1) * coupling / 7;
    forc1 = gamma * (sin(omega * omegaMult(0) * t1n) * (1-extAudioMix) + extAudio * extAudioMix) + coup1;
    dy1 = fY1 - (fY1*fY1*fY1) - (cMod2 * y1) + forc1;
    y1n = clamp100(y1 + dy1);
    x1n = distortion(distMode, x1 + (fY1 + y1n - x1) / smoothing);
    oL1 = fY1 * (1 - voicePan(0));
    oR1 = fY1 * voicePan(0);

    // Voice 2
    t2n = t2 + dt;
    fY2 = (x2 : filterBank(1)) * singleGain;
    coup2 = (xSum - x2) * coupling / 7;
    forc2 = gamma * (sin(omega * omegaMult(1) * t2n) * (1-extAudioMix) + extAudio * extAudioMix) + coup2;
    dy2 = fY2 - (fY2*fY2*fY2) - (cMod2 * y2) + forc2;
    y2n = clamp100(y2 + dy2);
    x2n = distortion(distMode, x2 + (fY2 + y2n - x2) / smoothing);
    oL2 = fY2 * (1 - voicePan(1));
    oR2 = fY2 * voicePan(1);

    // Voice 3
    t3n = t3 + dt;
    fY3 = (x3 : filterBank(2)) * singleGain;
    coup3 = (xSum - x3) * coupling / 7;
    forc3 = gamma * (sin(omega * omegaMult(2) * t3n) * (1-extAudioMix) + extAudio * extAudioMix) + coup3;
    dy3 = fY3 - (fY3*fY3*fY3) - (cMod2 * y3) + forc3;
    y3n = clamp100(y3 + dy3);
    x3n = distortion(distMode, x3 + (fY3 + y3n - x3) / smoothing);
    oL3 = fY3 * (1 - voicePan(2));
    oR3 = fY3 * voicePan(2);

    // Voice 4
    t4n = t4 + dt;
    fY4 = (x4 : filterBank(3)) * singleGain;
    coup4 = (xSum - x4) * coupling / 7;
    forc4 = gamma * (sin(omega * omegaMult(3) * t4n) * (1-extAudioMix) + extAudio * extAudioMix) + coup4;
    dy4 = fY4 - (fY4*fY4*fY4) - (cMod2 * y4) + forc4;
    y4n = clamp100(y4 + dy4);
    x4n = distortion(distMode, x4 + (fY4 + y4n - x4) / smoothing);
    oL4 = fY4 * (1 - voicePan(3));
    oR4 = fY4 * voicePan(3);

    // Voice 5
    t5n = t5 + dt;
    fY5 = (x5 : filterBank(4)) * singleGain;
    coup5 = (xSum - x5) * coupling / 7;
    forc5 = gamma * (sin(omega * omegaMult(4) * t5n) * (1-extAudioMix) + extAudio * extAudioMix) + coup5;
    dy5 = fY5 - (fY5*fY5*fY5) - (cMod2 * y5) + forc5;
    y5n = clamp100(y5 + dy5);
    x5n = distortion(distMode, x5 + (fY5 + y5n - x5) / smoothing);
    oL5 = fY5 * (1 - voicePan(4));
    oR5 = fY5 * voicePan(4);

    // Voice 6
    t6n = t6 + dt;
    fY6 = (x6 : filterBank(5)) * singleGain;
    coup6 = (xSum - x6) * coupling / 7;
    forc6 = gamma * (sin(omega * omegaMult(5) * t6n) * (1-extAudioMix) + extAudio * extAudioMix) + coup6;
    dy6 = fY6 - (fY6*fY6*fY6) - (cMod2 * y6) + forc6;
    y6n = clamp100(y6 + dy6);
    x6n = distortion(distMode, x6 + (fY6 + y6n - x6) / smoothing);
    oL6 = fY6 * (1 - voicePan(5));
    oR6 = fY6 * voicePan(5);

    // Voice 7
    t7n = t7 + dt;
    fY7 = (x7 : filterBank(6)) * singleGain;
    coup7 = (xSum - x7) * coupling / 7;
    forc7 = gamma * (sin(omega * omegaMult(6) * t7n) * (1-extAudioMix) + extAudio * extAudioMix) + coup7;
    dy7 = fY7 - (fY7*fY7*fY7) - (cMod2 * y7) + forc7;
    y7n = clamp100(y7 + dy7);
    x7n = distortion(distMode, x7 + (fY7 + y7n - x7) / smoothing);
    oL7 = fY7 * (1 - voicePan(6));
    oR7 = fY7 * voicePan(6);

    // Voice 8
    t8n = t8 + dt;
    fY8 = (x8 : filterBank(7)) * singleGain;
    coup8 = (xSum - x8) * coupling / 7;
    forc8 = gamma * (sin(omega * omegaMult(7) * t8n) * (1-extAudioMix) + extAudio * extAudioMix) + coup8;
    dy8 = fY8 - (fY8*fY8*fY8) - (cMod2 * y8) + forc8;
    y8n = clamp100(y8 + dy8);
    x8n = distortion(distMode, x8 + (fY8 + y8n - x8) / smoothing);
    oL8 = fY8 * (1 - voicePan(7));
    oR8 = fY8 * voicePan(7);

    mixOut = (oL1+oL2+oL3+oL4+oL5+oL6+oL7+oL8) * 0.125;
};

eightVoiceFeedback(
    oL1,oR1, x1,y1,t1, oL2,oR2, x2,y2,t2,
    oL3,oR3, x3,y3,t3, oL4,oR4, x4,y4,t4,
    oL5,oR5, x5,y5,t5, oL6,oR6, x6,y6,t6,
    oL7,oR7, x7,y7,t7, oL8,oR8, x8,y8,t8,
    mix
) = x1,y1,t1, x2,y2,t2, x3,y3,t3, x4,y4,t4,
    x5,y5,t5, x6,y6,t6, x7,y7,t7, x8,y8,t8, mix;

//==============================================================================
// MAIN PROCESS
//==============================================================================

sumStereo8(l1,r1,l2,r2,l3,r3,l4,r4,l5,r5,l6,r6,l7,r7,l8,r8) =
    ((l1+l2+l3+l4+l5+l6+l7+l8) * 0.125 : dcblock : *(outputGain)),
    ((r1+r2+r3+r4+r5+r6+r7+r8) * 0.125 : dcblock : *(outputGain));

processWithInput(inL, inR) = (eightVoiceSystem(audioMono) ~ eightVoiceFeedback) :
    (_, _, !, !, !,  _, _, !, !, !,  _, _, !, !, !,  _, _, !, !, !,
     _, _, !, !, !,  _, _, !, !, !,  _, _, !, !, !,  _, _, !, !, !, !) :
    sumStereo8
with {
    audioMono = (inL + inR) * 0.5;
};

process = _, _ : processWithInput;
