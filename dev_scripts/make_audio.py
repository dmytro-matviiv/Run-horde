# -*- coding: utf-8 -*-
"""Генерує звукові ефекти й музичну петлю для гри (WAV, 22050 Гц, моно).

Синтез, а не завантаження готових семплів: файли маленькі, ліцензійно
чисті й змінюються однією правкою чисел.
"""
import os
import wave

import numpy as np

RATE = 22050
OUT = r'D:\Claude code\idle survivor_like\assets\audio'
os.makedirs(OUT, exist_ok=True)


def save(name, samples, fade_out=0.01):
    x = np.asarray(samples, dtype=np.float64)
    # Короткий фейд, щоб не було клацання на початку й у кінці.
    n_fade = max(1, int(RATE * fade_out))
    x[:n_fade] *= np.linspace(0.0, 1.0, n_fade)
    x[-n_fade:] *= np.linspace(1.0, 0.0, n_fade)
    peak = np.max(np.abs(x)) or 1.0
    data = np.int16(np.clip(x / peak * 0.85, -1.0, 1.0) * 32767)
    path = os.path.join(OUT, name)
    with wave.open(path, 'w') as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(data.tobytes())
    print('%-22s %5.2f s' % (name, len(x) / RATE))


def t(duration):
    return np.linspace(0.0, duration, int(RATE * duration), endpoint=False)


def env(duration, attack=0.005, power=3.0):
    time = t(duration)
    a = np.clip(time / attack, 0.0, 1.0)
    return a * (1.0 - time / duration) ** power


def sweep(duration, f_start, f_end, wave_type='sine'):
    time = t(duration)
    freq = np.linspace(f_start, f_end, time.size)
    phase = 2.0 * np.pi * np.cumsum(freq) / RATE
    if wave_type == 'square':
        return np.sign(np.sin(phase))
    if wave_type == 'saw':
        return 2.0 * ((phase / (2.0 * np.pi)) % 1.0) - 1.0
    return np.sin(phase)


def noise(duration):
    rng = np.random.default_rng(7)
    return rng.uniform(-1.0, 1.0, int(RATE * duration))


def low_pass(x, strength=0.25):
    """Найпростіший однополюсний фільтр — прибирає різкість шуму."""
    out = np.zeros_like(x)
    acc = 0.0
    for i, value in enumerate(x):
        acc += strength * (value - acc)
        out[i] = acc
    return out


def note(freq, duration, kind='sine', power=2.5):
    return sweep(duration, freq, freq, kind) * env(duration, 0.01, power)


# --- бойові ефекти ---
save('sfx_shoot.wav', sweep(0.12, 760, 320, 'square') * env(0.12, 0.002, 4.0))
save('sfx_hit.wav', (noise(0.09) * 0.6 + sweep(0.09, 260, 120)) * env(0.09, 0.001, 5.0))
save('sfx_explosion.wav',
     (low_pass(noise(0.55), 0.18) * 1.2 + sweep(0.55, 180, 45)) * env(0.55, 0.004, 2.2))
save('sfx_enemy_death.wav',
     (sweep(0.3, 420, 90, 'saw') * 0.8 + noise(0.3) * 0.35) * env(0.3, 0.002, 3.0))
save('sfx_hero_hurt.wav',
     (sweep(0.28, 300, 110, 'saw') + low_pass(noise(0.28), 0.3) * 0.5) * env(0.28, 0.002, 2.5))
save('sfx_hero_death.wav',
     (sweep(0.9, 380, 60) + low_pass(noise(0.9), 0.12) * 0.4) * env(0.9, 0.01, 1.8))

# --- нагороди й меню ---
save('sfx_pickup.wav', sweep(0.13, 820, 1500) * env(0.13, 0.002, 3.5))
save('sfx_gold.wav',
     (note(1046, 0.09) + np.pad(note(1568, 0.1), (int(RATE * 0.05), 0))[:int(RATE * 0.09)]))
save('sfx_level_up.wav',
     np.concatenate([note(523, 0.12), note(659, 0.12), note(784, 0.12), note(1046, 0.3)]))
save('sfx_click.wav', sweep(0.05, 1300, 900, 'square') * env(0.05, 0.001, 5.0))
save('sfx_purchase.wav',
     np.concatenate([note(784, 0.12), note(988, 0.12), note(1318, 0.35)]))


def music_loop():
    """Темна підземна петля: бас, арпеджіо і тихий пульс. 8 тактів
    по 4 долі при 96 BPM — приблизно 20 секунд, зациклюється рівно."""
    bpm = 96.0
    beat = 60.0 / bpm
    bars = 8
    total = beat * 4 * bars
    track = np.zeros(int(RATE * total))

    def add(sample, at_seconds, gain=1.0):
        start = int(RATE * at_seconds)
        end = min(start + sample.size, track.size)
        track[start:end] += sample[:end - start] * gain

    # Ля-мінор: A2 бас під кожен такт, арпеджіо A-C-E-G зверху.
    bass_notes = [55.0, 55.0, 61.74, 61.74, 49.0, 49.0, 55.0, 55.0]
    arp = [220.0, 261.63, 329.63, 392.0]
    for bar in range(bars):
        bar_time = bar * beat * 4
        add(note(bass_notes[bar], beat * 3.4, 'saw', 1.4), bar_time, 0.55)
        for step in range(8):
            freq = arp[(bar + step) % len(arp)] * (2.0 if step % 4 == 3 else 1.0)
            add(note(freq, beat * 0.45, 'sine', 3.0), bar_time + step * beat * 0.5, 0.22)
        for pulse in range(4):
            add(low_pass(noise(0.08), 0.1) * env(0.08, 0.001, 4.0), bar_time + pulse * beat, 0.35)
    return track


save('music_dungeon.wav', music_loop(), fade_out=0.004)
print('готово:', OUT)
