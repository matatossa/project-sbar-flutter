# ---- Build stage ----
FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /workspace
# Copy only pom and wrapper first to leverage Docker layer caching
COPY e-learn/pom.xml ./e-learn/pom.xml
COPY e-learn/mvnw ./e-learn/mvnw
COPY e-learn/mvnw.cmd ./e-learn/mvnw.cmd
COPY e-learn/.mvn ./e-learn/.mvn
# Resolve dependencies
# Make Maven more resilient to flaky network
ENV MAVEN_OPTS="-Dmaven.wagon.http.retryHandler.count=5 -Dmaven.wagon.http.pool=false -Dmaven.wagon.http.connectionTimeout=60000 -Dmaven.wagon.http.readTimeout=60000"
RUN mvn -f e-learn/pom.xml -B -U -q -DskipTests dependency:go-offline || mvn -f e-learn/pom.xml -B -U -q -DskipTests dependency:go-offline
# Copy sources and build
COPY e-learn/src ./e-learn/src
RUN mvn -f e-learn/pom.xml -B -U -q -DskipTests clean package || mvn -f e-learn/pom.xml -B -U -q -DskipTests clean package

# ---- Runtime stage ----
FROM eclipse-temurin:17-jre
WORKDIR /app
COPY --from=build /workspace/e-learn/target/*-SNAPSHOT.jar app.jar
EXPOSE 8080
# Note: For docker-compose networking, ensure Spring points to service names: postgres, minio, vosk-proxy
ENTRYPOINT ["java","-jar","/app/app.jar"]

