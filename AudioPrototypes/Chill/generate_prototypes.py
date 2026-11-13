#!/usr/bin/env python3
"""Generate three original, phase-synchronized Chill breathing-tone prototypes."""

import math
from array import array
import wave
from pathlib import Path

SAMPLE_RATE = 44_100
PHASE_SECONDS = 5.0
CYCLE_SECONDS = 2 * PHASE_SECONDS
FADE_IN_SECONDS = 0.9
FADE_OUT_SECONDS = 1.1
PEAK_AMPLITUDE = 0.22
OUTPUT_DIR = Path(__file__).resolve().parent

VARIANTS = (
    {
        "filename": "Chill-Prototype-A-organic.wav",
        "description": "Organic, airy resonator",
        "fundamental_hz": 196.0,
        "partials": ((2.0, 0.20, 0.18), (3.0, 0.035, 0.41)),
    },
    {
        "filename": "Chill-Prototype-B-warm.wav",
        "description": "Round, warm, fuller body",
        "fundamental_hz": 174.61,
        "partials": ((2.0, 0.31, 0.10), (3.0, 0.12, 0.23), (4.0, 0.03, 0.37)),
    },
    {
        "filename": "Chill-Prototype-C-minimal.wav",
        "description": "Minimal, calm, nearly pure tone",
        "fundamental_hz": 220.0,
        "partials": ((2.0, 0.05, 0.0),),
    },
)


def smooth_envelope(phase_position: float) -> float:
    """Raised-cosine fade-in/out with a steady middle and zero-slope joins."""
    if phase_position < FADE_IN_SECONDS:
        progress = phase_position / FADE_IN_SECONDS
        return 0.5 - 0.5 * math.cos(math.pi * progress)

    fade_out_start = PHASE_SECONDS - FADE_OUT_SECONDS
    if phase_position > fade_out_start:
        progress = (phase_position - fade_out_start) / FADE_OUT_SECONDS
        return 0.5 + 0.5 * math.cos(math.pi * progress)

    return 1.0


def make_cycle(variant: dict) -> list[int]:
    frame_count = round(SAMPLE_RATE * CYCLE_SECONDS)
    frequency = variant["fundamental_hz"]
    partials = variant["partials"]
    raw = []
    raw_peak = 0.0

    for frame in range(frame_count):
        time = frame / SAMPLE_RATE
        phase_position = time % PHASE_SECONDS
        envelope = smooth_envelope(phase_position)
        fundamental = math.sin(2.0 * math.pi * frequency * time)
        tone = fundamental + math.fsum(
            level * math.sin(2.0 * math.pi * frequency * ratio * time + phase)
            for ratio, level, phase in partials
        )
        raw.append((tone, envelope))
        if envelope > 0.0:
            raw_peak = max(raw_peak, abs(tone * envelope))

    gain = PEAK_AMPLITUDE / raw_peak
    pcm = []
    for tone, envelope in raw:
        value = max(-1.0, min(1.0, gain * tone * envelope))
        pcm.append(round(value * 32767.0))
    return pcm


def write_wave(variant: dict) -> None:
    samples = make_cycle(variant)
    destination = OUTPUT_DIR / variant["filename"]
    with wave.open(str(destination), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(SAMPLE_RATE)
        wav.writeframes(array("h", samples).tobytes())
    print(f"{destination.name}: {len(samples)} mono PCM frames at {SAMPLE_RATE} Hz")


if __name__ == "__main__":
    for proposal in VARIANTS:
        write_wave(proposal)
