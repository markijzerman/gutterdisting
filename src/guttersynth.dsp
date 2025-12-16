// Guttersynth - Forced Damped Duffing Oscillator with Resonator Banks
// Port for Disting NT by M. IJzerman
// Original Guttersynth: Tom Mudd
//
// Version 0.1 - Minimal prototype
// - 1 voice, 2 filter banks, 8 filters per bank (16 total)
// - Core Duffing oscillator with sine forcing
// - Basic distortion modes

declare guid "GutS";
declare name "Gutter Synth";
declare description "Duffing oscillator with resonator banks";

import("stdfaust.lib");

//==============================================================================
// PARAMETERS
//==============================================================================

// Duffing oscillator parameters
gamma = hslider("h:[0]Duffing/[0]Forcing Amplitude (gamma)", 0.1, 0, 2, 0.001) : si.smoo;
omega = hslider("h:[0]Duffing/[1]Forcing Freq (omega)", 1.25, 0.1, 10, 0.01) : si.smoo;
c = hslider("h:[0]Duffing/[2]Damping (c)", 0.3, 0, 1, 0.001) : si.smoo;
dt = hslider("h:[0]Duffing/[3]Time Step (dt)", 1, 0.001, 10, 0.001) : si.smoo;

// Filter parameters
q = hslider("h:[1]Filters/[0]Resonance (Q)", 30, 0.5, 100, 0.1) : si.smoo;
smoothing = hslider("h:[1]Filters/[1]Smoothing", 1, 1, 10, 0.1) : si.smoo;

// Mix parameters
singleGain = hslider("h:[2]Mix/[0]Overall Gain", 0.5, 0, 2, 0.01) : si.smoo;
bank0Gain = hslider("h:[2]Mix/[1]Bank 0 Gain", 1, 0, 2, 0.01) : si.smoo;
bank1Gain = hslider("h:[2]Mix/[2]Bank 1 Gain", 0, 0, 2, 0.01) : si.smoo;

// Distortion mode (0-5)
distMode = nentry("h:[2]Mix/[3]Distortion Mode", 2, 0, 5, 1);

//==============================================================================
// FILTER FREQUENCIES
//==============================================================================

// Bank 0 - 8 filters
freq0_0 = 80;
freq0_1 = 120;
freq0_2 = 180;
freq0_3 = 250;
freq0_4 = 350;
freq0_5 = 500;
freq0_6 = 700;
freq0_7 = 1000;

// Bank 1 - 8 filters (scaled by 1.2 as per original)
freq1_0 = 96;
freq1_1 = 144;
freq1_2 = 216;
freq1_3 = 300;
freq1_4 = 420;
freq1_5 = 600;
freq1_6 = 840;
freq1_7 = 1200;

//==============================================================================
// DISTORTION FUNCTIONS
//==============================================================================

hardClip(x) = max(-1, min(1, x));

// Cubic with clipping: if x <= -1: -2/3, elif x >= 1: 2/3, else: x - x³/3
cubic(x) = ba.if(x <= -1, -0.666667, ba.if(x >= 1, 0.666667, x - (x*x*x)/3));

atanDist(x) = atan(x);

atanApprox(x) = 0.75 * (sqrt((x*1.3)*(x*1.3) + 1) * 1.65 - 1.65) / (x + 0.0001);

tanhApprox(x) = (0.1076*x*x*x + 3.029*x) / (x*x + 3.124);

sigmoid(x) = 2 / (1 + exp(-x));

distortion(mode, x) = ba.selectn(6, mode,
    hardClip(x),
    cubic(x),
    atanDist(x),
    atanApprox(x),
    tanhApprox(x),
    sigmoid(x)
);

//==============================================================================
// FILTER BANKS
//==============================================================================

// Single bandpass filter
bpFilter(freq, q_val) = fi.resonbp(freq, q_val, 1.0);

// Bank 0: 8 parallel filters summed
filterBank0 = par(i, 8,
    bpFilter(ba.take(i+1, (freq0_0, freq0_1, freq0_2, freq0_3,
                            freq0_4, freq0_5, freq0_6, freq0_7)), q)
) :> _;

// Bank 1: 8 parallel filters summed
filterBank1 = par(i, 8,
    bpFilter(ba.take(i+1, (freq1_0, freq1_1, freq1_2, freq1_3,
                            freq1_4, freq1_5, freq1_6, freq1_7)), q)
) :> _;

// Both banks mixed
filterBanks(x) = (x <: (filterBank0 * bank0Gain, filterBank1 * bank1Gain)) :> _;

//==============================================================================
// DUFFING OSCILLATOR
//==============================================================================

// Main Duffing system with feedback
// Takes 3 state variables from previous sample: (duffX, duffY, t)
// Outputs 4 values: (audio_output, duffX_new, duffY_new, t_new)
// NOTE: Audio output is FIRST so the ~ feedback operator feeds back the LAST 3 signals

duffingSystem(duffX_prev, duffY_prev, t_prev) = output, duffX_new, duffY_new, t_new
with {
    // Update time - scale dt down for audio rate (dt is a "speed" parameter, not actual timestep)
    // This scaling factor converts the dt parameter to work at audio rate
    t_new = t_prev + (dt * 0.001);

    // Forcing function
    forcing = gamma * sin(omega * t_new);

    // Apply distortion to previous duffX
    duffX_distorted = distortion(distMode, duffX_prev);

    // Process through filter banks
    finalY = duffX_distorted : filterBanks;

    // Duffing equation: dy = finalY - (finalY³) - (c·duffY) + forcing
    dy = finalY - (finalY*finalY*finalY) - (c * duffY_prev) + forcing;

    // Integrate: duffY += dy
    duffY_new = duffY_prev + dy;

    // dx = duffY
    dx = duffY_new;

    // Custom lowpass from original: duffX = (finalY + dx - duffX_prev) / smoothing
    duffX_new = (finalY + dx - duffX_prev) / smoothing;

    // Output is finalY scaled (as per original line 235)
    output = finalY * 0.125 * singleGain;
};

//==============================================================================
// MAIN PROCESS
//==============================================================================

// Feedback loop: state variables (duffX, duffY, t) feed back to next sample
// duffingSystem outputs: (audio, duffX, duffY, t)
// feedback() takes those 4 and returns 3 for the feedback loop
// The ~ operator still outputs all 4, so we select just audio (first), discard the rest
feedback(audio, duffX, duffY, t) = duffX, duffY, t;
process = (duffingSystem ~ feedback) : (_, !, !, !) <: (_, _);
