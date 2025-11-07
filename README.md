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

> Flutter app should be developed and run separately (see ./frontend for instructions).

---

### Project Structure

- `backend/` : Spring Boot project
- `frontend/`: Flutter project
- `vosk/`    : Config/scripts for Vosk ASR
- `docker-compose.yml`: Service launcher

---

**Next Steps:**
- Scaffold backend and frontend projects.
- Integrate Vosk ASR with backend.
