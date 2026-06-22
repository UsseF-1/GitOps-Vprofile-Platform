FROM maven:3.9.9-eclipse-temurin-21-jammy AS BUILD_IMAGE

LABEL "Project"="Vprofile"
LABEL "Author"="Youssef"

WORKDIR /app

COPY pom.xml .
COPY src ./src

RUN  mvn install -DskipTests

FROM tomcat:10-jdk21

RUN rm -rf /usr/local/tomcat/webapps/*
COPY --from=BUILD_IMAGE /app/target/vprofile-v2.war /usr/local/tomcat/webapps/ROOT.war

EXPOSE 8080
CMD ["catalina.sh", "run"]