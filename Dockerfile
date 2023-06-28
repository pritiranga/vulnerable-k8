FROM gradle:7.4.2-jdk11-alpine AS build
COPY --chown=gradle:gradle . /home/ubuntu
WORKDIR /home/ubuntu

# Build the application
RUN gradle build

FROM openjdk:8-jre-slim

RUN mkdir /app

COPY --from=build /home/ubuntu/build/libs/*.jar /app/vulnerable-application.jar

ENTRYPOINT ["java", "-XX:+UnlockExperimentalVMOptions", "-XX:+UseCGroupMemoryLimitForHeap", "-Djava.security.egd=file:/dev/./urandom","-jar","/app/vulnerable-application.jar"]

HEALTHCHECK NONE
