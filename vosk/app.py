import os
import json
import subprocess
import requests
from flask import Flask, request, jsonify
from websocket import create_connection, WebSocketConnectionClosedException
import time

VOSK_WS = os.getenv('VOSK_WS', 'ws://vosk:2700')
app = Flask(__name__)

@app.post('/recognize')
def recognize():
    data = request.get_json(silent=True) or {}
    video_url = data.get('videoUrl')
    if not video_url:
        return jsonify({'error': 'videoUrl required'}), 400
    if "localhost:9000" in video_url:
        video_url = video_url.replace("localhost:9000", "minio:9000")

    try:
        audio_path = '/tmp/audio.wav'
        cmd = [
            'ffmpeg', '-y', '-i', video_url,
            '-ac', '1', '-ar', '16000', '-f', 's16le', '-acodec', 'pcm_s16le', audio_path
        ]
        subprocess.run(cmd, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)

        ws = create_connection(VOSK_WS)
        ws.send(json.dumps({'config': {'sample_rate': 16000, 'words': True}}))

        with open(audio_path, 'rb') as af:
            while chunk := af.read(32000):  # larger chunk
                ws.send(chunk, opcode=0x2)
                time.sleep(0.01)  # small pause to prevent disconnect

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
                words.extend([{'word': w['word'], 'start': w['start'], 'end': w['end']} for w in obj['result']])
            if obj.get('final', False):
                break

        ws.close()
        return jsonify({'words': words})

    except Exception as e:
        return jsonify({'error': str(e), 'words': []}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8000)
