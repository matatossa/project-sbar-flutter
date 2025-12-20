# SBAR Project

An e-learning platform using Spring Boot for backend, Flutter for frontend (Android/Desktop), containerized with Docker Compose. Features integrated media player, video-to-text transcription, and a recommendation engine.

## Stack
- **Backend:** Spring Boot (Java)
- **Frontend:** Flutter (mobile + desktop)
- **Database:** PostgreSQL
- **Object Storage:** MinIO
- **Speech-to-Text:** Vosk (Docker)

## Getting Started

1. **Clone the repository**

2. **Start all services with Docker Compose**

```bash
docker-compose up --build
```

- Backend REST API: http://localhost:8080
- PostgreSQL: localhost:5432 (user: sbar, pass: sbarpass)
- MinIO Console: http://localhost:9001 (user/pass: minioadmin)
- Vosk Server (ASR): http://localhost:2700

3. **Setup MinIO Bucket for Video Storage**

After Docker Compose starts, you **must** create the bucket for video storage:

1. Open MinIO Console in your browser: http://localhost:9001
2. Login with credentials:
   - Username: `minioadmin`
   - Password: `minioadmin`
3. Click **"Create Bucket"** button (top right)
4. Enter bucket name: **`lesson-videos`** (exactly as shown)
5. **Keep the bucket PRIVATE** (default setting) - do not make it public
6. Click **"Create Bucket"**
7. The bucket is now ready for video uploads

> **Important:** 
> - The bucket name must be exactly `lesson-videos` as configured in the backend
> - The bucket should be **PRIVATE** (not public) - the backend uses credentials to access it and streams videos through its own endpoint
> - Without this bucket, video uploads will fail

> Flutter app should be developed and run separately (see ./frontend for instructions).

---

### Project Structure

- `backend/` : Spring Boot project
- `frontend/`: Flutter project
- `vosk/`    : Config/scripts for Vosk ASR
- `docker-compose.yml`: Service launcher

---

## Video Feature Setup

### Prerequisites
1. ✅ Docker Compose services running
2. ✅ MinIO bucket `lesson-videos` created (see step 3 above)

### Using the Video Feature

1. **Upload a Video (Admin only):**
   - Login as admin
   - Click "Add Course" button
   - Fill in course details and upload a video file
   - Video will be stored in MinIO bucket `lesson-videos`

2. **Generate Transcript (Admin only):**
   - Open a lesson with a video
   - If no transcript exists, click "Generate Transcript" button
   - Wait a few minutes for transcription to complete
   - Transcript will appear automatically when ready

### Troubleshooting

**Videos not uploading?**
- Verify MinIO bucket `lesson-videos` exists in MinIO Console
- Check backend logs: `docker logs sbar_backend`
- Ensure bucket name is exactly `lesson-videos` (case-sensitive)

**Transcript not generating?**
- Check Vosk service is running: `docker ps | grep vosk`
- Check backend logs for transcription errors
- Verify video has clear audio

**Courses disappear on page refresh?**
- This is normal if you're not logged in
- Login again to see your courses
- JWT token is stored in secure storage and persists across sessions

---

**Next Steps:**
- Scaffold backend and frontend projects.
- Integrate Vosk ASR with backend.
