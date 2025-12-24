# UI E2E Tests (Selenium)

The Selenium-based tests are opt-in so they do not run during a normal `mvn test`. Enable them only when the backend/minio stack is up.

## Prerequisites
- Google Chrome installed (WebDriverManager downloads the matching driver automatically).
- MinIO reachable at `http://localhost:9000` with the console on `http://localhost:9001`, credentials `minioadmin/minioadmin`.
  - Start with Docker: `docker run --name minio --rm -p 9000:9000 -p 9001:9001 -e MINIO_ROOT_USER=minioadmin -e MINIO_ROOT_PASSWORD=minioadmin minio/minio server /data --console-address :9001`
  - Create the bucket used by the app: `docker run --rm -e MC_HOST_minio=http://minioadmin:minioadmin@host.docker.internal:9000 minio/mc mb --ignore-existing minio/lesson-videos`
- Backend running with Swagger UI available (default `http://localhost:8080/swagger-ui/index.html`). If you do not have Postgres locally, start it with an in-memory H2 override:
  - `./mvnw spring-boot:run -Dspring.datasource.url=jdbc:h2:mem:e2e -Dspring.datasource.username=sa -Dspring.datasource.password= -Dspring.jpa.hibernate.ddl-auto=update -Dminio.url=http://localhost:9000 -Dminio.publicUrl=http://localhost:9000`

### Using docker-compose stack (recommended here)
- From the repo root (`project-sbar-flutter`), start the services: `docker compose up -d backend minio postgres vosk vosk-proxy`
- Create the bucket inside the compose network (one-time):  
  `docker run --rm --network project-sbar-flutter_default -e MC_HOST_minio=http://minioadmin:minioadmin@sbar_minio:9000 minio/mc mb --ignore-existing minio/lesson-videos`
- Base URLs from the host: backend `http://localhost:8080`, MinIO console `http://localhost:9001`.

## How to run
- Default `.\mvnw.cmd test` skips Selenium E2E. Enable them with either `-Pe2e` or `-De2e=true`.
- PowerShell needs quotes around any `-D` values containing `http://`.
- Run all tests (unit/integration + Selenium E2E) once the compose stack is up:  
  `.\mvnw.cmd -Pe2e test "-De2e.base-url=http://localhost:8080"`
- Run only the Selenium E2E tests:  
  `.\mvnw.cmd -Pe2e test "-De2e.base-url=http://localhost:8080" "-Dtest=*E2ETest"`
- If you prefer toggling without the profile:  
  `.\mvnw.cmd test "-De2e=true" "-De2e.base-url=http://localhost:8080"`  
  (add `"-Dheadless=false"` to see the browser).

Artifacts: screenshots on failures live in `target/selenium-screens/`; successful runs append a short summary to `target/selenium-report.txt`.
