# Vosk ASR HTTP Proxy

This service exposes a simple HTTP endpoint to transcribe a video URL using the Vosk server.

- POST /recognize
  - Body: { "videoUrl": "http://.../video.mp4" }
  - Response: { "words": [ { "word": "hello", "start": 0.01, "end": 0.20 }, ... ] }

## How it works
- Downloads the video from `videoUrl`
- Uses `ffmpeg` to extract 16kHz mono PCM audio
- Streams audio to the Vosk server (`ws://vosk:2700`) over WebSocket
- Aggregates partial/final results to a `words` array

## Run with docker-compose
- Ensure `vosk` (alphacep image) is up on port 2700
- Build and run this proxy alongside your stack
- Set backend property `asr.url=http://vosk-proxy:8000/recognize`

## Endpoints
- `POST /recognize` returns JSON with `words`
