"""Convert local Whisper segments to the Go replay API's timestamp format."""

import json
import sys

from pywhispercpp.model import Model


def main():
    model_path, audio_path, duration, use_gpu = sys.argv[1:]
    duration_ms = int(duration)
    model = Model(
        model_path,
        language="th",
        context_params={"use_gpu": use_gpu == "true"},
        print_progress=False,
        print_realtime=False,
        print_timestamps=False,
    )
    transcript = []
    for segment in model.transcribe(audio_path):
        # Whisper timestamps use centiseconds.
        start_ms = max(0, segment.t0 * 10)
        end_ms = min(duration_ms, segment.t1 * 10)
        text = segment.text.strip()
        if not text or end_ms <= start_ms:
            continue
        if transcript and start_ms <= transcript[-1]["startMs"]:
            continue
        transcript.append({"startMs": start_ms, "endMs": end_ms, "text": text})
    # Use ASCII escapes so redirected stdout works regardless of the locale.
    print(json.dumps(transcript))


if __name__ == "__main__":
    main()
