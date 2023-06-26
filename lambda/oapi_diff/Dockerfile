FROM gradle:7.3.3-jdk17 AS build
COPY . /app
WORKDIR /app
RUN gradle clean build

FROM public.ecr.aws/lambda/java:latest

# Copy function code and runtime dependencies from Gradle layout
COPY --from=build /app/build/classes/java/main ${LAMBDA_TASK_ROOT}
COPY --from=build /app/build/dependency/* ${LAMBDA_TASK_ROOT}/lib/

# Set the CMD to your handler (could also be done as a parameter override outside of the Dockerfile)
CMD [ "dev.karambol.Handler::handleRequest" ]
