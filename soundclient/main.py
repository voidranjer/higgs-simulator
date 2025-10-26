#!/usr/bin/env python3
"""
Live mic -> Enter to stop -> Google Cloud STT -> print transcript
Optional: POST { "message": "..." } to /message when --post is provided.

Deps:
  pip/uv install sounddevice google-cloud-speech requests python-dotenv

Auth:
  Set GOOGLE_APPLICATION_CREDENTIALS to your service-account JSON path.

Env (optional, .env in same folder):
  MESSAGE_ENDPOINT=http://localhost:9080/message
  LANGUAGE=en-US
  RATE=16000
"""

import os
import sys
import time
import argparse

try:
    from dotenv import load_dotenv
except ImportError:
    load_dotenv = lambda: None

import sounddevice as sd

# Lazy-import requests only if we actually POST
def post_message(endpoint: str, transcript: str):
    if not transcript or not transcript.strip():
        print("[warn] Empty transcript; skipping POST.")
        return None
    try:
        import requests
    except ImportError:
        print("[error] 'requests' not installed. Install it to enable POST.")
        return None
    try:
        resp = requests.post(endpoint, json={"message": transcript}, timeout=15)
        resp.raise_for_status()
        print(f"[ok] POSTed transcript to {endpoint} (status {resp.status_code})")
        return resp
    except requests.RequestException as e:
        print(f"[error] POST failed: {e}")
        return None


def record_until_enter(sample_rate: int, device_index: int | None) -> bytes:
    """
    Capture raw PCM (LINEAR16) mono audio until the user hits Enter.
    Returns raw bytes (no WAV header).
    """
    audio = bytearray()

    def cb(indata, frames, time_info, status):
        if status:
            # Over/underflows etc.
            print(f"[audio] {status}", file=sys.stderr)
        audio.extend(indata)

    stream_kwargs = dict(
        samplerate=sample_rate,
        channels=1,
        dtype="int16",
        blocksize=8000,  # ~0.5s at 16 kHz
        callback=cb,
    )
    if device_index is not None:
        stream_kwargs["device"] = (device_index, device_index)  # (input, output) use same index for input side

    print("🎙️ Recording… press ENTER to stop.")
    try:
        with sd.RawInputStream(**stream_kwargs):
            input()
    except KeyboardInterrupt:
        print("\n[info] Interrupted. Stopping.")
    except Exception as e:
        print(f"[error] Mic open failed: {e}")
        print("       - Pick a specific device with --input-device-index (see --list-devices)")
        print("       - On Windows, check mic privacy settings")
        sys.exit(1)

    if not audio:
        print("[error] No audio captured.")
        sys.exit(1)

    return bytes(audio)


def transcribe_gcloud_linear16(audio_bytes: bytes, sample_rate: int, language: str) -> str:
    """
    Transcribe raw LINEAR16 mono PCM with Google Cloud STT.
    Uses synchronous recognize for <= 60s; long_running_recognize otherwise.
    """
    if "GOOGLE_APPLICATION_CREDENTIALS" not in os.environ:
        print("[error] GOOGLE_APPLICATION_CREDENTIALS not set.")
        sys.exit(1)

    from google.cloud import speech

    client = speech.SpeechClient()

    audio = speech.RecognitionAudio(content=audio_bytes)
    config = speech.RecognitionConfig(
        encoding=speech.RecognitionConfig.AudioEncoding.LINEAR16,
        sample_rate_hertz=sample_rate,
        language_code=language,
        enable_automatic_punctuation=True,
        audio_channel_count=1,
        model="default",
    )

    duration_sec = len(audio_bytes) / (2 * sample_rate)  # 2 bytes/sample, mono
    if duration_sec > 60:
        print(f"[info] Audio ~{duration_sec:.1f}s. Using long_running_recognize…")
        op = client.long_running_recognize(config=config, audio=audio)
        resp = op.result(timeout=300)
    else:
        resp = client.recognize(config=config, audio=audio)

    parts = []
    for r in resp.results:
        if r.alternatives:
            parts.append(r.alternatives[0].transcript.strip())
    return " ".join(parts).strip()


def list_input_devices():
    try:
        import pyaudio
        pa = pyaudio.PyAudio()
        print("=== Input devices (index -> name) ===")
        for i in range(pa.get_device_count()):
            info = pa.get_device_info_by_index(i)
            if int(info.get("maxInputChannels", 0)) > 0:
                rate = int(info.get("defaultSampleRate", 0))
                print(f"{i:3d} -> {info.get('name')}  (ch={info.get('maxInputChannels')}, rate≈{rate} Hz)")
        pa.terminate()
    except Exception:
        # Fallback via sounddevice if PyAudio not present
        print("=== Input devices (index -> name) via sounddevice ===")
        try:
            for idx, dev in enumerate(sd.query_devices()):
                if dev.get("max_input_channels", 0) > 0:
                    print(f"{idx:3d} -> {dev.get('name')}  (ch={dev.get('max_input_channels')}, rate≈{int(dev.get('default_samplerate',0))} Hz)")
        except Exception as e:
            print(f"[warn] Could not list devices: {e}")


def main():
    load_dotenv()

    parser = argparse.ArgumentParser(description="Live transcription with Google Cloud STT; press Enter to stop")
    parser.add_argument("--endpoint", default=os.getenv("MESSAGE_ENDPOINT", "http://localhost:9080/message"),
                        help='HTTP endpoint to POST {"message": "..."}')
    parser.add_argument("--language", default=os.getenv("LANGUAGE", "en-US"),
                        help="BCP-47 code, e.g. en-US, fr-CA")
    parser.add_argument("--rate", type=int, default=int(os.getenv("RATE", "16000")),
                        help="Sample rate Hz (default 16000)")
    parser.add_argument("--input-device-index", type=int, default=None,
                        help="Audio input device index (see --list-devices)")
    parser.add_argument("--list-devices", action="store_true",
                        help="List available input devices and exit.")
    parser.add_argument("--post", action="store_true",
                        help="If set, POST the transcript after printing it.")
    args = parser.parse_args()

    if args.list_devices:
        list_input_devices()
        return

    print(f"[info] Endpoint:  {args.endpoint}")
    print(f"[info] Language:  {args.language}")
    print(f"[info] Rate:      {args.rate} Hz")
    if args.input_device_index is not None:
        print(f"[info] Mic idx:   {args.input_device_index}")
    # print("🎙️ Speak now… press ENTER to stop.")

    # 1) Record
    start = time.time()
    audio_bytes = record_until_enter(sample_rate=args.rate, device_index=args.input_device_index)
    dur = len(audio_bytes) / (2 * args.rate)
    print(f"[info] Captured ~{dur:.2f}s. Transcribing…")

    # 2) Transcribe
    text = transcribe_gcloud_linear16(audio_bytes, sample_rate=args.rate, language=args.language)

    # 3) Print (always)
    if text:
        print("\n===== TRANSCRIPT =====")
        print(text)
        print("======================\n")
    else:
        print("[warn] No text recognized.")

    # 4) Optional POST
    if args.post:
        post_message(args.endpoint, text)

    print("[done] ✨")


if __name__ == "__main__":
    main()
