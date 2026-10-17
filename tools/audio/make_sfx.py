"""战斗音效合成器（纯 Python，无第三方依赖）。

用法：
    python tools/audio/make_sfx.py            # 生成全部到 game/assets/audio/sfx/
    python tools/audio/make_sfx.py hit_light  # 只生成名字里含 hit_light 的

每个音效由几个简单零件拼成：带通噪声扫频（挥砍的风声）、扫频正弦（低频冲击）、
不谐和泛音（金属和冰的清脆感）、Karplus-Strong 拨弦（弩弦）、FM 钟声（提示音），
最后过一个小房间混响。随机数固定种子，同样的脚本永远生成同样的文件。
想换声音：改下面对应函数的参数后重跑；或者直接把 wav 换成你喜欢的素材，
游戏里引用的是 game/presentation/audio/combat_audio_style.tres 里的文件。
"""
import math
import os
import random
import struct
import sys
import wave

RATE = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "game", "assets", "audio", "sfx")


# ---------------------------------------------------------------- 基础零件
def silence(seconds):
    return [0.0] * int(seconds * RATE)


def mix(*tracks):
    length = max(len(t) for t in tracks)
    out = [0.0] * length
    for track in tracks:
        for i, v in enumerate(track):
            out[i] += v
    return out


def offset(track, seconds):
    return [0.0] * int(seconds * RATE) + track


def gain(track, amount):
    return [v * amount for v in track]


def envelope(n, attack, decay, curve=4.0, hold=0.0):
    """attack/hold/decay 以秒计；decay 段指数下降。"""
    a = max(1, int(attack * RATE))
    h = int(hold * RATE)
    out = []
    for i in range(n):
        if i < a:
            out.append((i / a) ** 1.5)
        elif i < a + h:
            out.append(1.0)
        else:
            t = (i - a - h) / max(1.0, decay * RATE)
            out.append(math.exp(-curve * t))
    return out


def apply(track, env):
    return [v * e for v, e in zip(track, env)]


def noise(seconds, rng):
    return [rng.uniform(-1.0, 1.0) for _ in range(int(seconds * RATE))]


def pink(seconds, rng):
    """近似粉噪声（Paul Kellet 滤波）：比白噪声柔和，风声不刺耳。"""
    b0 = b1 = b2 = b3 = b4 = b5 = b6 = 0.0
    out = []
    for _ in range(int(seconds * RATE)):
        w = rng.uniform(-1.0, 1.0)
        b0 = 0.99886 * b0 + w * 0.0555179
        b1 = 0.99332 * b1 + w * 0.0750759
        b2 = 0.96900 * b2 + w * 0.1538520
        b3 = 0.86650 * b3 + w * 0.3104856
        b4 = 0.55000 * b4 + w * 0.5329522
        b5 = -0.7616 * b5 - w * 0.0168980
        out.append((b0 + b1 + b2 + b3 + b4 + b5 + b6 + w * 0.5362) * 0.11)
        b6 = w * 0.115926
    return out


def svf(track, cutoff, q=0.7, mode="band"):
    """Chamberlin 状态变量滤波器。cutoff 可为常数或每样本列表（扫频）。"""
    low = band = 0.0
    damp = 1.0 / q
    out = []
    for i, x in enumerate(track):
        fc = cutoff[i] if isinstance(cutoff, list) else cutoff
        f = 2.0 * math.sin(math.pi * min(fc, RATE / 6.0) / RATE)
        low += f * band
        high = x - low - damp * band
        band += f * high
        out.append(band if mode == "band" else low if mode == "low" else high)
    return out


def sweep(n, start, end, shape=1.0):
    return [start * (end / start) ** ((i / max(1, n - 1)) ** shape) for i in range(n)]


def tone(seconds, freq_start, freq_end=None, wave_shape="sine", shape=1.0):
    n = int(seconds * RATE)
    freqs = sweep(n, freq_start, freq_end or freq_start, shape)
    phase = 0.0
    out = []
    for f in freqs:
        phase += 2.0 * math.pi * f / RATE
        if wave_shape == "sine":
            out.append(math.sin(phase))
        elif wave_shape == "tri":
            p = (phase / (2 * math.pi)) % 1.0
            out.append(4.0 * abs(p - 0.5) - 1.0)
        else:
            out.append(math.tanh(2.5 * math.sin(phase)))
    return out


def partials(seconds, freqs, decays, amps, rng=None, detune=0.0):
    """不谐和泛音：金属、冰、钟的“叮”。"""
    n = int(seconds * RATE)
    out = [0.0] * n
    for f, d, a in zip(freqs, decays, amps):
        if rng is not None and detune:
            f *= 1.0 + rng.uniform(-detune, detune)
        phase = rng.uniform(0, 6.28) if rng else 0.0
        step = 2.0 * math.pi * f / RATE
        for i in range(n):
            out[i] += a * math.sin(phase + step * i) * math.exp(-i / (d * RATE))
    return out


def fm_bell(seconds, carrier, ratio=1.4, index=3.0, decay=0.6):
    n = int(seconds * RATE)
    out = []
    for i in range(n):
        t = i / RATE
        env = math.exp(-t / decay)
        mod = index * env * math.sin(2 * math.pi * carrier * ratio * t)
        out.append(env * math.sin(2 * math.pi * carrier * t + mod))
    return out


def pluck(seconds, freq, rng, brightness=0.5):
    """Karplus-Strong 拨弦。"""
    period = int(RATE / freq)
    buf = [rng.uniform(-1, 1) for _ in range(period)]
    out = []
    for i in range(int(seconds * RATE)):
        j = i % period
        nxt = buf[(j + 1) % period]
        value = buf[j]
        buf[j] = (value * brightness + nxt * (1.0 - brightness)) * 0.996
        out.append(value)
    return out


def crackle(seconds, rng, density, decay=0.004):
    """随机细小脆响：冰裂、碎片。"""
    n = int(seconds * RATE)
    out = [0.0] * n
    clicks = int(density * seconds)
    for _ in range(clicks):
        start = int(rng.random() ** 1.6 * n)
        amp = rng.uniform(0.3, 1.0) * (1.0 - start / n)
        length = int(decay * RATE)
        for k in range(length):
            if start + k < n:
                out[start + k] += amp * rng.uniform(-1, 1) * math.exp(-k / (length / 3.0))
    return out


def soft_clip(track, drive=1.5):
    norm = math.tanh(drive)
    return [math.tanh(v * drive) / norm for v in track]


def reverb(track, wet=0.15, size=1.0, tail=0.6):
    """Schroeder 小房间混响：4 个梳状 + 2 个全通。"""
    combs = [int(d * size) for d in (1116, 1188, 1277, 1356)]
    feedback = 0.7 + 0.12 * tail
    out_len = len(track) + int(tail * RATE)
    dry = track + [0.0] * (out_len - len(track))
    acc = [0.0] * out_len
    for delay in combs:
        buf = [0.0] * delay
        damp_state = 0.0
        for i in range(out_len):
            j = i % delay
            y = buf[j]
            damp_state = y * 0.6 + damp_state * 0.4
            buf[j] = dry[i] + damp_state * feedback
            acc[i] += y * 0.25
    for delay in (556, 441):
        buf = [0.0] * delay
        for i in range(out_len):
            j = i % delay
            y = buf[j]
            buf[j] = acc[i] + y * 0.5
            acc[i] = y - acc[i] * 0.5
    return [d + w * wet for d, w in zip(dry, acc)]


def fade_out(track, seconds=0.02):
    n = int(seconds * RATE)
    for i in range(min(n, len(track))):
        track[-1 - i] *= i / n
    return track


def trim(track, threshold=0.0005):
    end = len(track)
    while end > 1 and abs(track[end - 1]) < threshold:
        end -= 1
    return track[:end]


def save(name, track, peak_db=-1.0):
    # 最后过一道温和的低通，去掉合成器常见的毛刺高频
    track = trim(fade_out(svf(list(track), 11000, q=0.7, mode="low")))
    peak = max(abs(v) for v in track) or 1.0
    target = 10 ** (peak_db / 20.0)
    scale = target / peak
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        handle.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, v * scale)) * 32767)) for v in track))
    print("wrote", os.path.relpath(path), "%.2fs" % (len(track) / RATE))


# ---------------------------------------------------------------- 音效
def whoosh(rng, seconds, f_start, f_end, q=1.6, attack=0.03, shape=0.7, tone_amount=0.0):
    n = int(seconds * RATE)
    # 两级带通：频带更窄，听起来是“呼”而不是“嘶”
    centre = sweep(n, f_start, f_end, shape)
    air = svf(svf(pink(seconds, rng), centre, q=q), centre, q=q)
    body = apply(air, envelope(n, attack, seconds * 0.55, curve=3.5, hold=seconds * 0.08))
    if tone_amount:
        ring = partials(seconds, [2350, 3170, 4720], [0.09, 0.07, 0.05], [0.5, 0.35, 0.2], rng, detune=0.03)
        body = mix(body, gain(offset(ring, attack * 0.8), tone_amount))
    return body


def swing(rng, variant):
    # 普攻：刀从耳边划过的“咻”——几乎瞬间起音、从高往低扫（像东西掠过），尾巴很短；每段音高略不同
    settings = [(0.15, 3200, 650), (0.15, 2800, 560), (0.16, 3600, 720)][variant]
    track = whoosh(rng, settings[0], settings[1], settings[2], q=1.9, attack=0.006, shape=0.45, tone_amount=0.12)
    return reverb(track, wet=0.05, size=0.7, tail=0.18)


def thrust(rng):
    # 第三段刺击：短促上扬
    track = whoosh(rng, 0.15, 900, 3000, q=2.2, attack=0.005, shape=0.4, tone_amount=0.25)
    return reverb(track, wet=0.08, size=0.8, tail=0.25)


def heavy_swing(rng):
    # 重击：低沉、厚重的“呼——”，起音快、从中频压到低频，尾巴稍长，起手带一点身体的力量感
    track = whoosh(rng, 0.3, 1600, 200, q=1.3, attack=0.012, shape=0.5)
    grunt = apply(svf(noise(0.16, rng), 260, q=2.5), envelope(int(0.16 * RATE), 0.01, 0.08))
    track = mix(track, gain(grunt, 0.4))
    return reverb(track, wet=0.1, size=1.0, tail=0.35)


def wave_cast(rng):
    # 剑气：风声 + 向下扫的共鸣“呼”+ 细碎闪光
    n = int(0.45 * RATE)
    roar = apply(svf(pink(0.45, rng), sweep(n, 1800, 380, 0.6), q=5.0), envelope(n, 0.01, 0.25, curve=3.0))
    shimmer = partials(0.4, [3300, 4410, 5950], [0.12, 0.09, 0.07], [0.4, 0.3, 0.2], rng, detune=0.02)
    track = mix(gain(roar, 0.9), whoosh(rng, 0.25, 600, 2400, q=1.5, attack=0.01), gain(shimmer, 0.25))
    return reverb(track, wet=0.14, size=1.0, tail=0.45)


def hit_light(rng, variant):
    # 命中：清脆的“啪” + 结实的低频“咚” + 一点肉感
    pitch = [1.0, 1.08, 0.93][variant]
    click = apply(svf(noise(0.03, rng), 2600 * pitch, q=0.9), envelope(int(0.03 * RATE), 0.0008, 0.008))
    thump = apply(tone(0.12, 150 * pitch, 55, shape=0.6), envelope(int(0.12 * RATE), 0.002, 0.05, curve=3.0))
    flesh = apply(svf(noise(0.09, rng), 700 * pitch, q=1.8), envelope(int(0.09 * RATE), 0.002, 0.03))
    track = mix(gain(click, 0.9), gain(thump, 1.0), gain(flesh, 0.6))
    return reverb(soft_clip(track, 1.8), wet=0.06, size=0.7, tail=0.2)


def hit_heavy(rng):
    click = apply(svf(noise(0.04, rng), 3000, q=0.8), envelope(int(0.04 * RATE), 0.001, 0.012))
    thump = apply(tone(0.25, 120, 38, shape=0.5), envelope(int(0.25 * RATE), 0.002, 0.11, curve=3.0))
    crunch = apply(svf(noise(0.2, rng), sweep(int(0.2 * RATE), 1800, 400), q=1.2), envelope(int(0.2 * RATE), 0.002, 0.07))
    track = mix(gain(click, 0.9), gain(thump, 1.2), gain(crunch, 0.7))
    return reverb(soft_clip(track, 2.4), wet=0.1, size=1.0, tail=0.35)


def kill(rng):
    # 击杀：重击感 + 向下的“噗”+ 一串上扬的小闪光，奖励感
    base = hit_heavy(rng)
    n = int(0.35 * RATE)
    poof = apply(svf(noise(0.35, rng), sweep(n, 2200, 300, 0.7), q=2.0), envelope(n, 0.01, 0.18))
    sparkle = mix(*[offset(fm_bell(0.35, f, ratio=2.76, index=1.2, decay=0.12), 0.05 + k * 0.035)
                    for k, f in enumerate((1568, 2093, 2637))])
    return mix(base, gain(offset(poof, 0.02), 0.5), gain(sparkle, 0.18))


def player_hurt(rng):
    # 主角受击：闷响 + 向下的低音，和打敌人的声音明显不同
    thud = apply(tone(0.22, 95, 45, shape=0.7), envelope(int(0.22 * RATE), 0.003, 0.09))
    body = apply(svf(noise(0.18, rng), 420, q=1.5), envelope(int(0.18 * RATE), 0.002, 0.06))
    groan = apply(tone(0.25, 330, 210, wave_shape="tri"), envelope(int(0.25 * RATE), 0.01, 0.1))
    groan = svf(groan, 900, q=0.8, mode="low")
    track = mix(gain(thud, 1.0), gain(body, 0.6), gain(groan, 0.35))
    return reverb(soft_clip(track, 2.0), wet=0.1, size=0.9, tail=0.3)


def dodge(rng):
    # 闪避：快而轻的风声 + 衣料抖动
    n = int(0.2 * RATE)
    air = svf(svf(pink(0.2, rng), sweep(n, 700, 2600, 0.5), q=1.2), sweep(n, 700, 2600, 0.5), q=1.2)
    flutter = [0.6 + 0.4 * math.sin(2 * math.pi * 34 * i / RATE) for i in range(n)]
    track = apply(apply(air, envelope(n, 0.015, 0.08, curve=3.0)), flutter)
    return reverb(track, wet=0.06, size=0.7, tail=0.2)


def freeze(rng):
    # 冻结：冰晶生长的清亮泛音 + 细碎冰裂 + 一口寒气
    shine = partials(0.9, [1318, 1976, 2637, 3951, 5274], [0.4, 0.32, 0.25, 0.16, 0.1],
                     [0.5, 0.45, 0.35, 0.18, 0.08], rng, detune=0.01)
    crack = svf(crackle(0.4, rng, 220, decay=0.004), 3200, q=0.9)
    n = int(0.45 * RATE)
    breath = apply(svf(pink(0.45, rng), sweep(n, 3500, 1500), q=1.0), envelope(n, 0.02, 0.2))
    track = mix(gain(shine, 0.55), gain(crack, 0.6), gain(breath, 0.25))
    return reverb(track, wet=0.2, size=1.1, tail=0.7)


def shatter(rng):
    # 碎冰：一声脆裂 + 很多玻璃般的碎片
    burst = apply(svf(noise(0.06, rng), 2500, q=0.7), envelope(int(0.06 * RATE), 0.0005, 0.02))
    shards = svf(crackle(0.5, rng, 600, decay=0.006), 3400, q=1.2)
    glass = partials(0.6, [1900, 2850, 4100, 5600], [0.12, 0.1, 0.08, 0.06], [0.4, 0.35, 0.3, 0.2], rng, detune=0.04)
    thump = apply(tone(0.15, 140, 60), envelope(int(0.15 * RATE), 0.001, 0.05))
    track = mix(gain(burst, 1.0), gain(shards, 0.8), gain(glass, 0.35), gain(thump, 0.6))
    return reverb(track, wet=0.18, size=1.0, tail=0.6)


def enemy_windup(rng):
    # 敌人前摇提示：金属出鞘般的上扬“铮——”，清楚但不刺耳
    n = int(0.32 * RATE)
    scrape = apply(svf(pink(0.32, rng), sweep(n, 1100, 2800, 0.8), q=6.0), envelope(n, 0.12, 0.12, curve=5.0))
    ring = apply(tone(0.32, 880, 1320, shape=1.4), envelope(n, 0.15, 0.1, curve=5.0))
    track = mix(gain(scrape, 0.7), gain(ring, 0.25))
    return reverb(track, wet=0.12, size=0.9, tail=0.3)


def heavy_windup(rng):
    # 重型敌人蓄力：低沉的上扬轰鸣，提示“这一下要躲”
    n = int(0.6 * RATE)
    rumble = apply(svf(noise(0.6, rng), sweep(n, 120, 520, 1.2), q=3.0), envelope(n, 0.4, 0.15, curve=5.0))
    drone = apply(tone(0.6, 70, 110, wave_shape="saw"), envelope(n, 0.45, 0.12, curve=5.0))
    drone = svf(drone, 600, q=0.9, mode="low")
    track = mix(gain(rumble, 0.9), gain(drone, 0.6))
    return reverb(soft_clip(track, 1.6), wet=0.1, size=1.0, tail=0.3)


def crossbow_shot(rng):
    # 弩/弓：弦的“嘣”+ 箭飞出的风声
    string = apply(pluck(0.25, 98, rng, brightness=0.55), envelope(int(0.25 * RATE), 0.001, 0.08))
    string = svf(string, 1800, q=0.7, mode="low")
    track = mix(gain(string, 1.0), gain(offset(whoosh(rng, 0.14, 1200, 3200, q=1.2, attack=0.005), 0.01), 0.45))
    return reverb(track, wet=0.08, size=0.8, tail=0.25)


def projectile_impact(rng):
    # 箭/弹命中地面或墙：木头般的“笃”
    knock = apply(tone(0.08, 420, 180), envelope(int(0.08 * RATE), 0.0008, 0.025))
    dust = apply(svf(noise(0.12, rng), 1200, q=0.8), envelope(int(0.12 * RATE), 0.002, 0.04))
    return reverb(mix(knock, gain(dust, 0.5)), wet=0.08, size=0.8, tail=0.2)


def charge_impact(rng):
    # 冲锋撞击：重的“砰”
    return mix(hit_heavy(rng), gain(apply(tone(0.3, 60, 32), envelope(int(0.3 * RATE), 0.002, 0.15)), 0.8))


def wave_start(rng):
    # 新一波敌人：低沉的战鼓两下
    def drum():
        body = apply(tone(0.4, 90, 48, shape=0.6), envelope(int(0.4 * RATE), 0.002, 0.16))
        skin = apply(svf(noise(0.1, rng), 900, q=1.0), envelope(int(0.1 * RATE), 0.001, 0.03))
        return mix(body, gain(skin, 0.4))
    track = mix(drum(), gain(offset(drum(), 0.22), 0.85))
    return reverb(soft_clip(track, 1.4), wet=0.2, size=1.2, tail=0.8)


def wave_clear(rng):
    # 清场：明亮的上行琶音钟声（C 大调）
    notes = (523.25, 659.25, 783.99, 1046.5)
    track = mix(*[gain(offset(fm_bell(1.2, f, ratio=3.5, index=1.6, decay=0.45), k * 0.09), 0.9 - k * 0.1)
                  for k, f in enumerate(notes)])
    return reverb(track, wet=0.3, size=1.3, tail=1.0)


def ui_choose(rng):
    # 选卡：柔和的两声钟
    track = mix(fm_bell(0.6, 880, ratio=2.0, index=1.0, decay=0.25), gain(offset(fm_bell(0.7, 1318.5, ratio=2.0, index=1.0, decay=0.3), 0.07), 0.8))
    return reverb(track, wet=0.25, size=1.1, tail=0.7)


def armor_hit(rng):
    # 打在霸体上：短促的金属“铛”，告诉玩家这一下没打断它
    clank = partials(0.35, [620, 1450, 2330, 3410], [0.09, 0.07, 0.05, 0.035], [0.6, 0.5, 0.35, 0.2], rng, detune=0.02)
    knock = apply(tone(0.08, 210, 120), envelope(int(0.08 * RATE), 0.001, 0.025))
    tick = apply(svf(noise(0.02, rng), 3000, q=1.0), envelope(int(0.02 * RATE), 0.0005, 0.006))
    track = mix(gain(clank, 0.7), gain(knock, 0.6), gain(tick, 0.5))
    return reverb(track, wet=0.14, size=0.9, tail=0.4)


def guard_break(rng):
    # 破防：沉重的碎裂 + 金属崩开 + 低频轰，明显的奖励感
    n = int(0.6 * RATE)
    crunch = apply(svf(noise(0.6, rng), sweep(n, 2400, 300, 0.6), q=1.3), envelope(n, 0.002, 0.2))
    clang = partials(0.8, [480, 1130, 1870, 2950], [0.25, 0.18, 0.12, 0.08], [0.6, 0.45, 0.3, 0.18], rng, detune=0.03)
    boom = apply(tone(0.5, 90, 34, shape=0.5), envelope(int(0.5 * RATE), 0.002, 0.22))
    track = mix(gain(crunch, 0.8), gain(clang, 0.5), gain(boom, 1.1))
    return reverb(soft_clip(track, 2.0), wet=0.2, size=1.2, tail=0.7)


def ignite(rng):
    # 点燃：呼的一声火起
    n = int(0.45 * RATE)
    roar = apply(svf(pink(0.45, rng), sweep(n, 300, 1400, 0.5), q=1.2), envelope(n, 0.03, 0.2))
    crackle_ = svf(crackle(0.45, rng, 90, decay=0.003), 2500, q=0.8)
    return reverb(mix(gain(roar, 1.0), gain(crackle_, 0.35)), wet=0.1, size=0.9, tail=0.3)


def zap(rng):
    # 电击：短促的噼啪与嗡鸣
    n = int(0.3 * RATE)
    buzz = apply(tone(0.3, 110, 90, wave_shape="saw"), envelope(n, 0.002, 0.1))
    buzz = svf(buzz, 2600, q=0.8, mode="low")
    snap = svf(crackle(0.25, rng, 260, decay=0.002), 3500, q=0.7)
    return reverb(mix(gain(buzz, 0.6), gain(snap, 0.9)), wet=0.1, size=0.8, tail=0.25)


def rock(rng):
    # 碎甲：沉闷的石块撞击
    knock = apply(tone(0.18, 160, 70), envelope(int(0.18 * RATE), 0.001, 0.05))
    grit = apply(svf(pink(0.2, rng), 900, q=0.9), envelope(int(0.2 * RATE), 0.002, 0.06))
    chips = svf(crackle(0.25, rng, 60, decay=0.004), 1800, q=1.0)
    return reverb(mix(gain(knock, 1.0), gain(grit, 0.6), gain(chips, 0.4)), wet=0.1, size=0.9, tail=0.3)


def steam(rng):
    # 蒸腾：一声爆响接长长的蒸汽嘶声
    n = int(1.0 * RATE)
    hiss = apply(svf(noise(1.0, rng), sweep(n, 5000, 2200, 0.6), q=0.8), envelope(n, 0.01, 0.45, curve=2.5))
    pop = hit_heavy(rng)
    return mix(gain(pop, 0.9), gain(reverb(hiss, wet=0.2, size=1.1, tail=0.5), 0.6))


def overload(rng):
    # 过载：火雷爆炸——低频轰鸣 + 电噼啪
    n = int(0.8 * RATE)
    boom = apply(tone(0.8, 85, 30, shape=0.5), envelope(n, 0.002, 0.3))
    blast = apply(svf(noise(0.8, rng), sweep(n, 3000, 250, 0.6), q=0.9), envelope(n, 0.002, 0.22))
    snap = svf(crackle(0.4, rng, 300, decay=0.002), 3200, q=0.8)
    track = mix(gain(boom, 1.2), gain(blast, 0.8), gain(snap, 0.5))
    return reverb(soft_clip(track, 2.2), wet=0.22, size=1.3, tail=0.8)


def lava(rng):
    # 熔岩：嘶的一声落地，接咕嘟冒泡
    n = int(1.0 * RATE)
    sizzle = apply(svf(noise(1.0, rng), 3800, q=0.7), envelope(n, 0.01, 0.35))
    bubbles = [0.0] * n
    for _ in range(14):
        start = int(rng.uniform(0.05, 0.85) * n)
        f = rng.uniform(140, 320)
        blip = apply(tone(0.06, f, f * 1.8), envelope(int(0.06 * RATE), 0.004, 0.02))
        for i, v in enumerate(blip):
            if start + i < n:
                bubbles[start + i] += v * 0.6
    thud = apply(tone(0.3, 110, 45), envelope(int(0.3 * RATE), 0.002, 0.1))
    return reverb(mix(gain(sizzle, 0.5), bubbles, gain(thud, 0.9)), wet=0.15, size=1.0, tail=0.4)


def superconduct(rng):
    # 超导：冰晶清响 + 电流嗡鸣下沉
    shine = partials(0.8, [1568, 2349, 3136], [0.3, 0.22, 0.15], [0.5, 0.35, 0.2], rng, detune=0.01)
    n = int(0.8 * RATE)
    hum = svf(apply(tone(0.8, 220, 80, wave_shape="saw"), envelope(n, 0.01, 0.35)), 1500, q=1.0, mode="low")
    snap = svf(crackle(0.3, rng, 200, decay=0.002), 3000, q=0.8)
    return reverb(mix(gain(shine, 0.5), gain(hum, 0.6), gain(snap, 0.5)), wet=0.22, size=1.1, tail=0.6)


def magnet(rng):
    # 磁暴：向内收拢的“呜——嗡”
    n = int(0.7 * RATE)
    suck = apply(svf(pink(0.7, rng), sweep(n, 3000, 300, 1.4), q=3.0), envelope(n, 0.3, 0.15, curve=5.0))
    hum = svf(apply(tone(0.7, 60, 140, wave_shape="saw"), envelope(n, 0.25, 0.2, curve=4.0)), 900, q=1.2, mode="low")
    thump = offset(apply(tone(0.25, 120, 50), envelope(int(0.25 * RATE), 0.002, 0.08)), 0.4)
    return reverb(soft_clip(mix(gain(suck, 0.8), gain(hum, 0.6), gain(thump, 1.0)), 1.6), wet=0.18, size=1.1, tail=0.5)


def build_all(only=None):
    jobs = {
        "swing_1": lambda r: swing(r, 0),
        "swing_2": lambda r: swing(r, 1),
        "swing_3": lambda r: swing(r, 2),
        "thrust": thrust,
        "heavy_swing": heavy_swing,
        "wave_cast": wave_cast,
        "hit_light_1": lambda r: hit_light(r, 0),
        "hit_light_2": lambda r: hit_light(r, 1),
        "hit_light_3": lambda r: hit_light(r, 2),
        "hit_heavy": hit_heavy,
        "kill": kill,
        "player_hurt": player_hurt,
        "dodge": dodge,
        "freeze": freeze,
        "shatter": shatter,
        "enemy_windup": enemy_windup,
        "heavy_windup": heavy_windup,
        "crossbow_shot": crossbow_shot,
        "projectile_impact": projectile_impact,
        "charge_impact": charge_impact,
        "wave_start": wave_start,
        "wave_clear": wave_clear,
        "ui_choose": ui_choose,
        "armor_hit": armor_hit,
        "guard_break": guard_break,
        "ignite": ignite,
        "zap": zap,
        "rock": rock,
        "steam": steam,
        "overload": overload,
        "lava": lava,
        "superconduct": superconduct,
        "magnet": magnet,
    }
    for index, (name, job) in enumerate(jobs.items()):
        if only and only not in name:
            continue
        save(name, job(random.Random(1000 + index)))


if __name__ == "__main__":
    build_all(sys.argv[1] if len(sys.argv) > 1 else None)
