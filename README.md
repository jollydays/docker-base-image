# Jollydays Microservice Base Image

Base Image used by Jollydays to run microservices on Openshift.

This image does the following:
* Runs a Java Application from a Jar (java 8)
* Runs the NewRelic Agent for Application Performance Monitoring
* Exposes JMX via Jolokia
* Kills itself on OutOfMemory Errors (and optionally uploads a heap dump to Amazon S3)

## Usage:

Use this image as  a base image for your java application. The executed Jar File can be set with the JAR environment
variable. Java Options can be set with the JAVA_OPTIONS variable. In order to use NewRelic you must set the "newrelic.config.license_key"
property in the java options:

```
FROM jollydays/base-image:latest

# Specify the name of the service / docker image
ENV SERVICE_NAME myservice

# This variable will be set by Kubernetes if ran in a k8s environment
ENV KUBERNETES_NAMESPACE

# Add the jar
COPY my.jar /maven/

# Set Java options, in order to use NewRelic, set the license key property
ENV JAVA_OPTIONS -Xmx128M -Dnewrelic.config.license_key=xxxxx
ENV JAR my.jar

# Set Amazon credentials if memory dumps should be uploaded
ENV AWS_ACCESS_KEY_ID XXX
ENV AWS_SECRET_ACCESS_KEY XXX
ENV AWS_DEFAULT_REGION XXX
ENV S3_BUCKET memdumps
```

## Credits:
* https://developer.atlassian.com/blog/2015/08/minimal-java-docker-containers/
* https://github.com/fabric8io/java-docker
* https://github.com/legdba/javaw
* https://github.com/anigeo/docker-awscli/blob/master/Dockerfile
