#!/usr/bin/env python3
"""Озвучка реплик из voice/lines.json.

Каждая реплика синтезируется нейросетевым голосом Piper, затем ffmpeg накладывает
эффект рации (узкая полоса, перегруз, компрессия, шипение) и сохраняет voice/<id>.ogg.
Уже озвученные реплики с неизменённым текстом пропускаются (voice/manifest.json).

Запуск (так делает workflow .github/workflows/voice.yml):
    python tools/voice/generate.py <модель-диспетчера.onnx> <модель-обходчика.onnx> <модель-Маши.onnx>
"""
import hashlib
import json
import os
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
VOICE_DIR = os.path.join(ROOT, "voice")
VERSION = "1"  # поменять, чтобы переозвучить всё заново

# Голос диспетчера идёт через рацию, голос обходчика — «живой», рядом.
RADIO = (
    "[0:a]aresample=22050,highpass=f=320,lowpass=f=3300,"
    "acrusher=bits=10:mix=0.35:mode=log,"
    "acompressor=threshold=0.08:ratio=6:attack=5:release=80:makeup=3,"
    "apad=pad_dur=0.25[v];"
    "anoisesrc=color=pink:amplitude=0.03:sample_rate=22050[n];"
    "[v][n]amix=inputs=2:duration=first:weights=1 0.7:normalize=0"
)
NEAR = (
    "[0:a]aresample=22050,highpass=f=90,lowpass=f=7000,"
    "acompressor=threshold=0.15:ratio=3:makeup=2,apad=pad_dur=0.15"
)
# Маша: женский голос, поднятый на треть выше (детский), — в тоннеле с гулким эхом, в трубке — телефонная полоса.
CHILD = "aresample=22050,asetrate=22050*1.3,aresample=22050,atempo=0.85,"
ECHO = (
    "[0:a]" + CHILD + "highpass=f=180,lowpass=f=5200,"
    "aecho=0.8:0.6:140|310:0.35|0.18,apad=pad_dur=0.8"
)
PHONE = (
    "[0:a]" + CHILD + "highpass=f=400,lowpass=f=3000,"
    "acompressor=threshold=0.1:ratio=5:makeup=3,apad=pad_dur=0.3[v];"
    "anoisesrc=color=brown:amplitude=0.02:sample_rate=22050[n];"
    "[v][n]amix=inputs=2:duration=first:weights=1 0.5:normalize=0"
)
SPEAKERS = {
    "dispatcher": {"model": "dispatcher", "length_scale": "1.12", "filter": RADIO},
    "player": {"model": "player", "length_scale": "1.0", "filter": NEAR},
    "masha": {"model": "masha", "length_scale": "1.2", "filter": ECHO},
    "masha_phone": {"model": "masha", "length_scale": "1.15", "filter": PHONE},
}


def prepare(text: str) -> str:
    # Тире и многоточия — паузы; синтезатору понятнее запятые и точки.
    return text.replace(" — ", ", ").replace("—", ", ").replace("...", ". ").replace("…", ". ").strip(" .") + "."


def main() -> None:
    models = {"dispatcher": sys.argv[1], "player": sys.argv[2], "masha": sys.argv[3]}
    data = json.load(open(os.path.join(VOICE_DIR, "lines.json"), encoding="utf-8"))
    manifest_path = os.path.join(VOICE_DIR, "manifest.json")
    manifest = json.load(open(manifest_path, encoding="utf-8")) if os.path.exists(manifest_path) else {}
    lines = data["lines"]
    done = 0
    for line_id, entry in lines.items():
        speaker = entry["speaker"]
        text = entry["text"]
        digest = hashlib.sha1(f"{VERSION}|{speaker}|{text}".encode()).hexdigest()
        out = os.path.join(VOICE_DIR, f"{line_id}.ogg")
        if manifest.get(line_id) == digest and os.path.exists(out):
            continue
        cfg = SPEAKERS[speaker]
        with tempfile.TemporaryDirectory() as tmp:
            wav = os.path.join(tmp, "raw.wav")
            subprocess.run(
                ["piper", "-m", models[cfg["model"]], "-f", wav,
                 "--length_scale", cfg["length_scale"], "--sentence_silence", "0.3"],
                input=prepare(text).encode("utf-8"), check=True, capture_output=True)
            subprocess.run(
                ["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-filter_complex", cfg["filter"],
                 "-ac", "1", "-c:a", "libvorbis", "-q:a", "4", out],
                check=True)
        manifest[line_id] = digest
        done += 1
        print(f"{line_id}: {text}")
    # Убрать озвучку реплик, которых больше нет.
    for name in os.listdir(VOICE_DIR):
        if name.endswith(".ogg") and name[:-4] not in lines:
            os.remove(os.path.join(VOICE_DIR, name))
            manifest.pop(name[:-4], None)
    json.dump(manifest, open(manifest_path, "w", encoding="utf-8"), ensure_ascii=False, indent=1, sort_keys=True)
    print(f"Озвучено реплик: {done}, всего: {len(lines)}")


if __name__ == "__main__":
    main()
