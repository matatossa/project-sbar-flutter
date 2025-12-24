# UI E2E Tests (Selenium)

The Selenium-based tests are opt-in so they do not run during a normal `mvn test`. Enable them when you have the UI stack running.

## Prerequisites
- Google Chrome installed (WebDriverManager downloads the matching driver automatically).
- MinIO reachable at `http://localhost:9000` with the console on `http://localhost:9001`, credentials `minioadmin/minioadmin`.
  - Start with Docker: `docker run --name minio --rm -p 9000:9000 -p 9001:9001 -e MINIO_ROOT_USER=minioadmin -e MINIO_ROOT_PASSWORD=minioadmin minio/minio server /data --console-address :9001`
  - Create the bucket used by the app: `docker run --rm -e MC_HOST_minio=http://minioadmin:minioadmin@host.docker.internal:9000 minio/mc mb --ignore-existing minio/lesson-videos`
- Backend running with Swagger UI available (default `http://localhost:8080/swagger-ui/index.html`). If you do not have Postgres locally, start it with an in-memory H2 override:
  - `./mvnw spring-boot:run -Dspring.datasource.url=jdbc:h2:mem:e2e -Dspring.datasource.username=sa -Dspring.datasource.password= -Dspring.jpa.hibernate.ddl-auto=update -Dminio.url=http://localhost:9000 -Dminio.publicUrl=http://localhost:9000`

### Using docker-compose stack (recommended here)
- From the repo root (`project-sbar-flutter`), start the services: `docker-compose up -d backend minio postgres vosk vosk-proxy`
- Create the bucket inside the compose network (one-time):  
  `docker run --rm --network project-sbar-flutter_default -e MC_HOST_minio=http://minioadmin:minioadmin@sbar_minio:9000 minio/mc mb --ignore-existing minio/lesson-videos`
- Base URLs from the host: backend `http://localhost:8080`, MinIO console `http://localhost:9001`.

## How to run
- Enable the tests via the Maven profile (sets `-De2e=true` automatically) and keep headless Chrome:
  - `./mvnw -Pe2e test -De2e.base-url=http://localhost:8080`
- Or flip it on explicitly without the profile:
  - `E2E=true ./mvnw test` (add `-Dheadless=false` if you want to see the browser).

Screenshots on failures are written to `target/selenium-screens/`.
