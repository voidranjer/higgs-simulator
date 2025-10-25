#!/usr/bin/env python3
"""
Live mic -> Enter to stop -> RealtimeSTT (local Whisper) -> POST /message

Usage:
  python live_transcribe_post_realtimestt.py \
    --endpoint http://localhost:8000/message --model tiny --language en --device cpu

Env overrides via .env:
  MESSAGE_ENDPOINT, STT_MODEL, LANGUAGE, DEVICE
"""

import os
import sys
import argparse
import requests

try:
    from dotenv import load_dotenv
except ImportError:
    load_dotenv = lambda: None  # .env optional

# RealtimeSTT quick-start uses start()/stop()/text() for manual recording
# (we mirror that flow here).
try:
    from RealtimeSTT import AudioToTextRecorder
except Exception as e:
    print(f"[error] RealtimeSTT import failed: {e}")
    print("       pip install RealtimeSTT")
    sys.exit(1)


def post_message(endpoint: str, transcript: str):
    if not transcript or not transcript.strip():
        print("[warn] Empty transcript; skipping POST.")
        return None
    try:
        resp = requests.post(endpoint, json={"message": transcript}, timeout=15)
        resp.raise_for_status()
        print(f"[ok] POSTed transcript to {endpoint} (status {resp.status_code})")
        return resp
    except requests.RequestException as e:
        print(f"[error] POST failed: {e}")
        return None


def main():
    load_dotenv()

    parser = argparse.ArgumentParser(
        description="Live transcription with RealtimeSTT, stop on Enter, POST JSON to /message"
    )
    parser.add_argument(
        "--endpoint",
        default=os.getenv("MESSAGE_ENDPOINT", "http://localhost:8000/message"),
        help='HTTP endpoint to POST {"message": "..."}',
    )
    parser.add_argument(
        "--model",
        default=os.getenv("STT_MODEL", "tiny"),
        help="Whisper model (tiny, base, small, medium, large, or local path)",
    )
    parser.add_argument(
        "--language",
        default=os.getenv("LANGUAGE", ""),
        help="Language code ('' = auto-detect). e.g., en, fr, de, vi",
    )
    parser.add_argument(
        "--device",
        default=os.getenv("DEVICE", "cpu"),
        choices=["cpu", "cuda"],
        help="Inference device",
    )

    args = parser.parse_args()

    print(f"[info] Endpoint:  {args.endpoint}")
    print(f"[info] Model:     {args.model}")
    print(f"[info] Language:  {args.language or '(auto)'}")
    print(f"[info] Device:    {args.device}")
    print("🎙️ Speak now… press ENTER to stop recording.")

    # Manual start/stop like in the docs
    try:
        recorder = AudioToTextRecorder(
            model=args.model,
            language=args.language,
            device=args.device,
            spinner=False,
        )
    except Exception as e:
        print(f"[error] Failed to init AudioToTextRecorder: {e}")
        sys.exit(1)

    try:
        recorder.start()
        input()  # wait for Enter
        recorder.stop()
    except KeyboardInterrupt:
        print("\n[info] Interrupted; stopping.")
        try:
            recorder.stop()
        except Exception:
            pass

    try:
        transcript = recorder.text()
    except Exception as e:
        print(f"[error] Failed to get transcription: {e}")
        transcript = ""

    if transcript:
        print("\n===== TRANSCRIPT =====")
        print(transcript)
        print("======================\n")
    else:
        print("[warn] No text recognized.")

    post_message(args.endpoint, transcript)

    try:
        recorder.shutdown()
    except Exception:
        pass

    print("[done] ✨")


if __name__ == "__main__":
    main()
