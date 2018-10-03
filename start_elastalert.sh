#!/bin/sh
# Here is the fork of [1], more like a minimal version
# [1] https://github.com/krizsan/elastalert-docker/blob/master/start-elastalert.sh

set -e

# Set schema and elastalert options
case "${ELASTICSEARCH_TLS}:${ELASTICSEARCH_TLS_VERIFY}" in
    True:True)
        WGET_SCHEMA='https://'
        WGET_OPTIONS='-q -T 3'
        CREATE_EA_OPTIONS='--ssl --verify-certs'
    ;;
    True:False)
        WGET_SCHEMA='https://'
        WGET_OPTIONS='-q -T 3 --no-check-certificate'
        CREATE_EA_OPTIONS='--ssl --no-verify-certs'
    ;;
    *)
        WGET_SCHEMA='http://'
        WGET_OPTIONS='-q -T 3'
        CREATE_EA_OPTIONS='--no-ssl'
    ;;
esac

# Wait until Elasticsearch is online since otherwise Elastalert will fail.
while ! wget ${WGET_OPTIONS} -O - "${WGET_SCHEMA}${WGET_AUTH}${ELASTICSEARCH_HOST}:${ELASTICSEARCH_PORT}" 2>/dev/null
do
    echo "Waiting for Elasticsearch..."
    sleep 1
done
sleep 5

# Check if the Elastalert index exists in Elasticsearch and create it if it does not.
if ! wget ${WGET_OPTIONS} -O - "${WGET_SCHEMA}${WGET_AUTH}${ELASTICSEARCH_HOST}:${ELASTICSEARCH_PORT}/${ELASTALERT_INDEX}" 2>/dev/null
then
    echo "Creating Elastalert index in Elasticsearch..."
    elastalert-create-index ${CREATE_EA_OPTIONS} \
        --host "${ELASTICSEARCH_HOST}" \
        --port "${ELASTICSEARCH_PORT}" \
        --config "${ELASTALERT_CONFIG}" \
        --index "${ELASTALERT_INDEX}" \
        --old-index ""
else
    echo "Elastalert index already exists in Elasticsearch."
fi

echo "Starting Elastalert..."
exec supervisord -c "${ELASTALERT_SUPERVISOR_CONF}" -n
