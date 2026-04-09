# ──────────────────────────────────────────────────────────────────
# Dockerfile — Multi-stage build for the Vprofile Java/Tomcat application
#
# Stage 1: Build the WAR file with Maven
# Stage 2: Copy WAR into a lean Tomcat runtime image
#
# This keeps the final image small by not including the JDK or Maven.
# ──────────────────────────────────────────────────────────────────

# ── Stage 1: Build ────────────────────────────────────────────────
FROM maven:3.9.4-eclipse-temurin-17 AS BUILD_IMAGE

# Set working directory inside the build container
WORKDIR /app

# Copy dependency descriptor first — Docker caches this layer separately.
# The Maven dependencies are only re-downloaded when pom.xml changes.
COPY pom.xml .
RUN mvn dependency:go-offline -B

# Copy application source and build the WAR artifact
COPY src ./src
RUN mvn install -DskipTests

# ── Stage 2: Runtime ──────────────────────────────────────────────
FROM tomcat:9.0-jdk17-temurin-jammy

# Remove the default ROOT webapp to avoid port conflicts
RUN rm -rf /usr/local/tomcat/webapps/*

# Copy the built WAR from stage 1 into Tomcat's webapps directory.
# Naming it ROOT.war deploys it at the context root (/).
COPY --from=BUILD_IMAGE /app/target/vprofileapp-v2.war /usr/local/tomcat/webapps/ROOT.war

# Expose port 8080 — this is Tomcat's default HTTP port
EXPOSE 8080

# Start Tomcat in foreground so Docker can track the process
CMD ["catalina.sh", "run"]
