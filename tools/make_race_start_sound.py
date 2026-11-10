# -*- coding: utf-8 -*-
"""Generate a race-start double-beep sound (assets/sounds/race_start.wav).

Classic start-pistol-ish "beep beep": two short bright bursts with a fast
attack/decay so it cuts through phone speakers.
"""
import math
import struct
import wave

SR = 44100


def burst(freq: float, dur: float, vol: float = 0.9, attack: float = 0.005,
          decay_tail: float = 0.03):
    n = int(SR * dur)
    out = []
    for i in range(n):
        t = i / SR
        env = 1.0
        if t < attack:
            env = t / attack
        tail = max(0.0, 1.0 - (t - (dur - decay_tail)) / decay_tail)
        env = min(env, tail)
        # a touch of 2nd harmonic for brightness
        s = math.sin(2 * math.pi * freq * t) + 0.35 * math.sin(
            2 * math.pi * freq * 2 * t)
        out.append(vol * env * s)
    return out


def silence(dur: float):
    return [0.0] * int(SR * dur)


def write_wav(path: str, samples):
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        frames = bytearray()
        for s in samples:
            v = max(-1.0, min(1.0, s))
            frames += struct.pack('<h', int(v * 32767))
        w.writeframes(bytes(frames))


if __name__ == '__main__':
    # "beep ... beep!" — first shorter/lower, second longer/higher.
    samples = (
        burst(880, 0.14, vol=0.9)
        + silence(0.07)
        + burst(1174, 0.30, vol=0.95)
        + silence(0.10)
    )
    write_wav('assets/sounds/race_start.wav', samples)
    print('written assets/sounds/race_start.wav '
          f'({len(samples) / SR:.2f}s)')
