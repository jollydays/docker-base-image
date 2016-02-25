FROM alpine:3.3

MAINTAINER stefan.unterhofer@jollydays.com

# Install AWS cli (see https://github.com/anigeo/docker-awscli/blob/master/Dockerfile)
RUN apk -Uuv add groff less python py-pip && \
	pip install awscli && \
	apk --purge -v del py-pip && \
	rm /var/cache/apk/*

# Install Java 8
# Install cURL
RUN apk --update add curl ca-certificates tar && \
    curl -Ls https://github.com/andyshinn/alpine-pkg-glibc/releases/download/2.23-r1/glibc-2.23-r1.apk > /tmp/glibc-2.23-r1.apk && \
    apk add --allow-untrusted /tmp/glibc-2.23-r1.apk

# Java Version
ENV JAVA_VERSION_MAJOR 8
ENV JAVA_VERSION_MINOR 74
ENV JAVA_VERSION_BUILD 02
ENV JAVA_PACKAGE       jdk

# Download and unarchive Java
RUN mkdir /opt && curl -jksSLH "Cookie: oraclelicense=accept-securebackup-cookie"\
  http://download.oracle.com/otn-pub/java/jdk/${JAVA_VERSION_MAJOR}u${JAVA_VERSION_MINOR}-b${JAVA_VERSION_BUILD}/${JAVA_PACKAGE}-${JAVA_VERSION_MAJOR}u${JAVA_VERSION_MINOR}-linux-x64.tar.gz \
    | tar -xzf - -C /opt &&\
    ln -s /opt/jdk1.${JAVA_VERSION_MAJOR}.0_${JAVA_VERSION_MINOR} /opt/jdk &&\
    rm -rf /opt/jdk/*src.zip \
           /opt/jdk/lib/missioncontrol \
           /opt/jdk/lib/visualvm \
           /opt/jdk/lib/*javafx* \
           /opt/jdk/jre/lib/plugin.jar \
           /opt/jdk/jre/lib/ext/jfxrt.jar \
           /opt/jdk/jre/bin/javaws \
           /opt/jdk/jre/lib/javaws.jar \
           /opt/jdk/jre/lib/desktop \
           /opt/jdk/jre/plugin \
           /opt/jdk/jre/lib/deploy* \
           /opt/jdk/jre/lib/*javafx* \
           /opt/jdk/jre/lib/*jfx* \
           /opt/jdk/jre/lib/amd64/libdecora_sse.so \
           /opt/jdk/jre/lib/amd64/libprism_*.so \
           /opt/jdk/jre/lib/amd64/libfxplugins.so \
           /opt/jdk/jre/lib/amd64/libglass.so \
           /opt/jdk/jre/lib/amd64/libgstreamer-lite.so \
           /opt/jdk/jre/lib/amd64/libjavafx*.so \
           /opt/jdk/jre/lib/amd64/libjfx*.so

# Set environment
ENV JAVA_HOME /opt/jdk
ENV PATH ${PATH}:${JAVA_HOME}/bin

# Install Bash
RUN apk add --update bash && rm -rf /var/cache/apk/*

# Install Bouncycastle Security Provider (fix for invalid prime number connection error)
# See http://stackoverflow.com/questions/6851461/java-why-does-ssl-handshake-give-could-not-generate-dh-keypair-exception
ENV BC_VERSION=jdk15on-154
RUN curl -jksSL http://bouncycastle.org/download/bcprov-$BC_VERSION.jar > $JAVA_HOME/jre/lib/ext/bcprov-$BC_VERSION.jar &&\
    curl -jksSL http://bouncycastle.org/download/bcprov-ext-$BC_VERSION.jar > $JAVA_HOME/jre/lib/ext/bcprov-ext-$BC_VERSION.jar
COPY java.security /opt/jdk/jre/lib/security/

# Add dns config, see https://github.com/gliderlabs/docker-alpine/issues/11
RUN echo 'hosts: files mdns4_minimal [NOTFOUND=return] dns mdns4' >> /etc/nsswitch.conf

# Add Jolokia
ENV JOLOKIA_VERSION 1.3.1
ADD jolokia_opts /bin/
RUN chmod 755 /bin/jolokia_opts && mkdir /opt/jolokia && wget http://central.maven.org/maven2/org/jolokia/jolokia-jvm/1.3.1/jolokia-jvm-1.3.1-agent.jar -O /opt/jolokia/jolokia.jar
CMD java -jar /opt/jolokia/jolokia.jar --version

# Add fabric8 scripts
ENV CLASSPATH /maven/*:/maven
RUN mkdir /maven
EXPOSE 8778
run mkdir /fabric8

# add custom run script + newrelic
ADD run.sh /fabric8/
COPY newrelic.jar /fabric8/
COPY newrelic.yml /fabric8/

CMD [ "/fabric8/run.sh" ]
