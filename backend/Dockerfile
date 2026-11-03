FROM maven:3.9.11-eclipse-temurin-21 AS build
WORKDIR /app
COPY pom.xml .
RUN mvn -B dependency:go-offline
COPY src ./src
RUN mvn -B verify

FROM eclipse-temurin:21-jre-alpine
RUN addgroup -S mealgo && adduser -S mealgo -G mealgo
WORKDIR /app
COPY --from=build --chown=mealgo:mealgo /app/target/backend-0.0.1-SNAPSHOT.jar app.jar
USER mealgo
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
