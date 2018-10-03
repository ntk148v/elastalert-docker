# Elasalert Docker image running on Alpine Linux
FROM python:2.7-alpine3.8 as builder
LABEL maintainer="Kien Nguyen-Tuan, kiennt2609@gmail.com"
# Make it works behind the proxy - comment these out if you don't use proxy
ARG http_proxy
ARG https_proxy
# Elastalert version
ARG ELASTALERT_VERSION
ENV ELASTALERT_VERSION ${ELASTALERT_VERSION}
# URL from which to download Elastalert.
ENV ELASTALERT_URL https://github.com/Yelp/elastalert/archive/${ELASTALERT_VERSION}.zip
# Elastalert home directory full path
ENV ELASTALERT_HOME /opt/elastalert

WORKDIR /opt
RUN pip install supervisor
# Install software required for Elastalert
RUN apk update && \
    apk upgrade && \
    apk add --no-cache ca-certificates openssl-dev openssl py2-yaml libffi-dev gcc musl-dev wget && \
    wget -O elastalert.zip "${ELASTALERT_URL}" && \
    unzip elastalert.zip && \
    rm elastalert.zip && \
    mv e* "${ELASTALERT_HOME}"

WORKDIR "${ELASTALERT_HOME}"

# Install Elastalert.
# see: https://github.com/Yelp/elastalert/issues/1654
RUN sed -i 's/jira>=1.0.10/jira>=1.0.10,<1.0.15/g' setup.py && \
    python setup.py install && \
    pip install -r requirements.txt

FROM python:2.7-alpine3.8
LABEL maintainer="Kien Nguyen-Tuan, kiennt2609@gmail.com"

## Make it works behind the proxy - comment these out if you don't use proxy
ARG http_proxy
ARG https_proxy

# Set timezone for container
ENV TZ Asia/Ho_Chi_Minh
# Directory holding configuration for Elastalert and Supervisor.
ENV CONFIG_DIR /opt/config
# Elastalert rules directory.
ENV RULES_DIRECTORY /opt/rules
# Elastalert configuration file path in configuration directory.
ENV ELASTALERT_CONFIG ${CONFIG_DIR}/elastalert_config.yaml
# Directory to which Elastalert and Supervisor logs are written.
ENV LOG_DIR /opt/logs
# Elastalert home directory full path.
ENV ELASTALERT_HOME /opt/elastalert
# Supervisor configuration file for Elastalert.
ENV ELASTALERT_SUPERVISOR_CONF ${CONFIG_DIR}/elastalert_supervisord.conf
# Alias, DNS or IP of Elasticsearch host to be queried by Elastalert. Set in default Elasticsearch configuration file.
ENV ELASTICSEARCH_HOST elasticsearchhost
# Port on above Elasticsearch host. Set in default Elasticsearch configuration file.
ENV ELASTICSEARCH_PORT 9200
# Use TLS to connect to Elasticsearch (True or False)
ENV ELASTICSEARCH_TLS False
# Verify TLS
ENV ELASTICSEARCH_TLS_VERIFY True
# ElastAlert writeback index
ENV ELASTALERT_INDEX elastalert_status

COPY --from=builder /usr/lib/python2.7/site-packages /usr/lib/python2.7/site-packages
COPY --from=builder /opt/elastalert /opt/elastalert
COPY --from=builder /usr/local/bin/elastalert* /usr/bin/
COPY --from=builder /usr/local/bin/supervisord /usr/bin/supervisord

RUN apk add --update --no-cache tzdata && \
# Create directories.
    mkdir -p "${CONFIG_DIR}" && \
    mkdir -p "${RULES_DIRECTORY}" && \
    mkdir -p "${LOG_DIR}"

# Copy the script used to launch the Elastalert when container is started
COPY ./start_elastalert.sh /opt/
# Make the start-script executabe
RUN chmod +x /opt/start_elastalert.sh

# Define mount points
VOLUME [ "${CONFIG_DIR}", "${RULES_DIRECTORY}", "${LOG_DIR}"]

# Launch Elastalert when a container is started
CMD ["/opt/start_elastalert.sh"]
