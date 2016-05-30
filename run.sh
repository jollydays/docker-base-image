#!/usr/bin/env bash

_ctrlc() {
    echo "Caught Ctrl^C signal"
    kill -TERM $child 2>/dev/null
    wait "$child"
    exit $?
}

_term() {
    echo "Caught SIGTERM signal"
    kill -TERM $child 2>/dev/null
    wait "$child"
    exit $?
}

if [ -z ${NEWRELIC_OFF+x} -o "$NEWRELIC_OFF" != "true" ]; then
   NEWRELIC_OPTS="-javaagent:/fabric8/newrelic.jar"
fi

export JAVA_OPTIONS="$JAVA_OPTIONS $(jolokia_opts) $NEWRELIC_OPTS"

PROCESS_NAME="$SERVICE_NAME-$KUBERNETES_NAMESPACE"

if [ -n "$AWS_ACCESS_KEY_ID" ] && [ -n "$AWS_SECRET_ACCESS_KEY" ]; then
    echo "AWS credentials set, will upload heap dumps on OOM";
    HEAP_DUMP_ON_OOM="-XX:+HeapDumpOnOutOfMemoryError"
    ON_OOM="aws s3 cp *.hprof s3://$S3_BUCKET/$PROCESS_NAME/`date "+%Y-%m-%dT%H:%M:%S"`/; kill -9 %p";
else
    echo "AWS credentials NOT set, will not upload heap dumps on OOM"
    HEAP_DUMP_ON_OOM=""
    ON_OOM="kill -9 %p"
fi

echo "Starting Docker Image"
echo "env SERVICE_NAME=$SERVICE_NAME"
echo "env KUBERNETES_NAMESPACE=$KUBERNETES_NAMESPACE"
echo "env MAIN=$MAIN"
echo "env JAVA_HOME=$JAVA_HOME"
echo "env JAVA_OPTIONS=$JAVA_OPTIONS"
echo "env JAR=$JAR"
echo "env CLASSPATH=$CLASSPATH"
echo "env ON_OOM=$ON_OOM"
echo "env HEAP_DUMP_ON_OOM=$HEAP_DUMP_ON_OOM"
echo "env PROCESS_NAME=$PROCESS_NAME"
echo "env JOLOKIA_OFF=$JOLOKIA_OFF"
echo "env NEWRELIC_OFF=$NEWRELIC_OFF"

if [ "$$" -eq "1" ]
then
    # We run as PID 1, which means we are a regular contains
    # and java would fail to auto-kill itself because PID 1
    # cannot received kill -9.
    # -> We start a child process, trap signals and propagate them.
    trap _term SIGTERM
    trap _ctrlc INT
    if [ -n "$MAIN" ]; then
      echo java $HEAP_DUMP_ON_OOM -XX:OnOutOfMemoryError="$ON_OOM" -Dnewrelic.config.app_name=$PROCESS_NAME $JAVA_OPTIONS -cp $CLASSPATH $MAIN $ARGUMENTS
      java $HEAP_DUMP_ON_OOM -XX:OnOutOfMemoryError="$ON_OOM" -Dnewrelic.config.app_name=$PROCESS_NAME $JAVA_OPTIONS -cp $CLASSPATH $MAIN $ARGUMENTS
    else
      echo java $HEAP_DUMP_ON_OOM -XX:OnOutOfMemoryError="$ON_OOM" -Dnewrelic.config.app_name=$PROCESS_NAME $JAVA_OPTIONS -jar "/maven/$JAR" $ARGUMENTS
      java $HEAP_DUMP_ON_OOM -XX:OnOutOfMemoryError="$ON_OOM" -Dnewrelic.config.app_name=$PROCESS_NAME $JAVA_OPTIONS -jar "/maven/$JAR" $ARGUMENTS
    fi
    exit 1
else
    # We don't run as PID 1, which means we are a lucky container,
    # probably run with "/bin/sh -c" or a Kubernetes POD container.
    # Java will be able to auto-kill itself so we don't need to
    # do anything :)
    if [ -n "$MAIN" ]; then
      echo $JAVA_HOME/bin/java $HEAP_DUMP_ON_OOM -XX:OnOutOfMemoryError="$ON_OOM" -Dnewrelic.config.app_name=$PROCESS_NAME $JAVA_OPTIONS -cp $CLASSPATH $MAIN $ARGUMENTS
      exec $JAVA_HOME/bin/java $HEAP_DUMP_ON_OOM -XX:OnOutOfMemoryError="$ON_OOM" -Dnewrelic.config.app_name=$PROCESS_NAME $JAVA_OPTIONS -cp $CLASSPATH $MAIN $ARGUMENTS
    else
      echo $JAVA_HOME/bin/java $HEAP_DUMP_ON_OOM -XX:OnOutOfMemoryError="$ON_OOM" -Dnewrelic.config.app_name=$PROCESS_NAME $JAVA_OPTIONS -jar "/maven/$JAR" $ARGUMENTS
      exec $JAVA_HOME/bin/java $HEAP_DUMP_ON_OOM -XX:OnOutOfMemoryError="$ON_OOM" -Dnewrelic.config.app_name=$PROCESS_NAME $JAVA_OPTIONS -jar "/maven/$JAR" $ARGUMENTS
    fi
fi
