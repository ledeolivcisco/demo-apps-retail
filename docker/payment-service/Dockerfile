# syntax=docker/dockerfile:1
# Build context: repository root (WALLMART).
FROM maven:3.9.9-eclipse-temurin-21-alpine AS builder
WORKDIR /build
COPY ecommerce/pom.xml .
COPY ecommerce/session-support/pom.xml session-support/
COPY ecommerce/db-support/pom.xml db-support/
COPY ecommerce/product-service/pom.xml product-service/
COPY ecommerce/cart-service/pom.xml cart-service/
COPY ecommerce/payment-service/pom.xml payment-service/
COPY ecommerce/session-support/src session-support/src
COPY ecommerce/db-support/src db-support/src
COPY ecommerce/payment-service/src payment-service/src
RUN mvn -q -pl payment-service -am -DskipTests package

FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
RUN addgroup -g 1001 app && adduser -u 1001 -G app -D app
COPY --from=builder /build/payment-service/target/payment-service-*.jar /app/app.jar
RUN chown app:app /app/app.jar \
    && mkdir -p /tmp/appdynamics && chown app:app /tmp/appdynamics
USER app
EXPOSE 8083
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
