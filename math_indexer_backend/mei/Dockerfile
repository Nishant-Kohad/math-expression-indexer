FROM eclipse-temurin:17-jdk-alpine
WORKDIR /app
COPY . .
RUN ./mvnw package -DskipTests
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "target/mei-0.0.1-SNAPSHOT.jar"]
