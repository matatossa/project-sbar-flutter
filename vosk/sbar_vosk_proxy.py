import os
import json
import tempfile
import subprocess
from flask import Flask, request, jsonify
from websocket import create_connection, WebSocketConnectionClosedException

VOSK_WS = os.getenv('VOSK_WS', 'ws://vosk:2700')
CHUNK_SECONDS = 30  # Each audio segment length in seconds

app = Flask(__name__)

def transcribe_segment(audio_path):
    """Transcribe a single audio segment via Vosk WebSocket"""
    ws = create_connection(VOSK_WS)
    ws.send(json.dumps({'config': {'sample_rate': 16000}}))
    try:
        with open(audio_path, 'rb') as af:
            while True:
                chunk = af.read(4000)
                if not chunk:
                    break
                ws.send(chunk, opcode=0x2)
        ws.send(json.dumps({'eof': 1}))
        words = []
        while True:
            try:
                msg = ws.recv()
            except WebSocketConnectionClosedException:
                break
            if not msg:
                break
            obj = json.loads(msg)
            if 'result' in obj:
                for w in obj['result']:
                    words.append({
                        'word': w.get('word', ''),
                        'start': float(w.get('start', 0.0)),
                        'end': float(w.get('end', 0.0))
                    })
            if obj.get('final', False):
                break
        return words
    finally:
        ws.close()

@app.post('/recognize')
def recognize():
    data = request.get_json(silent=True) or {}
    video_url = data.get('videoUrl')
    if not video_url:
        return jsonify({'error': 'videoUrl required'}), 400

    # Docker: replace localhost with service name if needed
    if "localhost:9000" in video_url:
        video_url = video_url.replace("localhost:9000", "minio:9000")

    try:
        with tempfile.TemporaryDirectory() as td:
            video_path = os.path.join(td, 'input.mp4')
            # Download video
            import requests
            with requests.get(video_url, stream=True, timeout=60) as r:
                r.raise_for_status()
                with open(video_path, 'wb') as f:
                    for chunk in r.iter_content(chunk_size=8192):
                        if chunk:
                            f.write(chunk)

            # Determine video duration
            cmd_duration = ['ffprobe', '-v', 'error', '-show_entries',
                            'format=duration', '-of',
                            'default=noprint_wrappers=1:nokey=1', video_path]
            duration = float(subprocess.check_output(cmd_duration).decode().strip())
            segments = []
            start = 0
            while start < duration:
                end = min(start + CHUNK_SECONDS, duration)
                audio_path = os.path.join(td, f'audio_{int(start)}.wav')
                cmd_extract = [
                    'ffmpeg', '-y', '-i', video_path,
                    '-ss', str(start), '-to', str(end),
                    '-ac', '1', '-ar', '16000', '-f', 's16le',
                    '-acodec', 'pcm_s16le', audio_path
                ]
                subprocess.run(cmd_extract, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                segments.append(audio_path)
                start = end

            # Transcribe all segments
            all_words = []
            for seg_path in segments:
                all_words.extend(transcribe_segment(seg_path))

            return jsonify({'words': all_words})
    except Exception as e:
        return jsonify({'error': str(e), 'words': []}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8000)