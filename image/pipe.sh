#!/usr/bin/env bash
#
# Deploy to a Pagely app with a CICD integration - https://pagely.com
# Required globals:
#     PAGELY_DEPLOY_DEST
#     PAGELY_INTEGRATION_SECRET
#     PAGELY_INTEGRATION_ID
#     PAGELY_APP_ID
#
# Optional globals:
#     PAGELY_WORKING_DIR (default: "$PWD" - the default will be the GitHub workspace)

set -o errexit
set -o pipefail
set -o nounset

PAGELY_DEPLOY_DEST="${INPUT_PAGELY_DEPLOY_DEST:-${PAGELY_DEPLOY_DEST:-}}"
PAGELY_INTEGRATION_SECRET="${INPUT_PAGELY_INTEGRATION_SECRET:-${PAGELY_INTEGRATION_SECRET:-}}"
PAGELY_INTEGRATION_ID="${INPUT_PAGELY_INTEGRATION_ID:-${PAGELY_INTEGRATION_ID:-}}"
PAGELY_APP_ID="${INPUT_PAGELY_APP_ID:-${PAGELY_APP_ID:-}}"
PAGELY_WORKING_DIR="${INPUT_PAGELY_WORKING_DIR:-${PAGELY_WORKING_DIR:-"$(pwd)"}}"

if [[ -z "${PAGELY_DEPLOY_DEST}" ]]; then
    echo "PAGELY_DEPLOY_DEST is required"
    exit 1
fi
if [[ -z "${PAGELY_INTEGRATION_SECRET}" ]]; then
    echo "PAGELY_INTEGRATION_SECRET is required"
    exit 1
fi
if [[ -z "${PAGELY_APP_ID}" ]]; then
    echo "PAGELY_APP_ID is required"
    exit 1
fi
if [[ -z "${PAGELY_WORKING_DIR}" ]]; then
    echo "PAGELY_WORKING_DIR is required"
    exit 1
fi


echo "Running deploy with the following settings: "
echo "PAGELY_DEPLOY_DEST: ${PAGELY_DEPLOY_DEST}"
echo "PAGELY_INTEGRATION_ID: ${PAGELY_INTEGRATION_ID}"
echo "PAGELY_APP_ID: ${PAGELY_APP_ID}"
echo "PAGELY_WORKING_DIR: ${PAGELY_WORKING_DIR}"


outputGroupStart ()
{
    echo "::group::$1"
}

outputGroupEnd ()
{
    echo "::endgroup::"
}

# Tar everything in the directory as requested
outputGroupStart "Tarball from the contents of the working dir"
tar --exclude-vcs -zcvf /tmp/deploy.tar.gz -C "${PAGELY_WORKING_DIR}" .
ls -lh /tmp/deploy.tar.gz
outputGroupEnd

URL_LOOKUP_OUTPUT="$(mktemp)"
URL_LOOKUP_URL="https://mgmt.pagely.com/api/apps/integration/${PAGELY_INTEGRATION_ID}/endpoint?appId=${PAGELY_APP_ID}"

echo "Lookup app's deployment URL"
if http --check-status --ignore-stdin --timeout=10 GET "${URL_LOOKUP_URL}" \
    "X-Token: ${PAGELY_INTEGRATION_SECRET}" \
    > "${URL_LOOKUP_OUTPUT}"
then
    DEPLOY_URL="$(cat "${URL_LOOKUP_OUTPUT}")&tail=1"
    echo "Successfully got deployment URL"
else
    HTTP_EXIT_CODE=$?

    echo "FAILURE in request to ${URL_LOOKUP_URL}"
    case ${HTTP_EXIT_CODE} in
        2) echo 'Request timed out!' ;;
        3) echo 'Unexpected HTTP 3xx Redirection!' ;;
        4) echo 'HTTP 4xx Client Error!';;
        5) echo 'HTTP 5xx Server Error!' ;;
        6) echo 'Exceeded --max-redirects=<n> redirects!' ;;
        *) echo 'Other Error!' ;;
    esac
    cat "${URL_LOOKUP_OUTPUT}"
    exit 1
fi

echo "Running deploy..."
DEPLOY_OUTPUT="$(mktemp)"
DEPLOY_HTTP_CODE_FILE="$(mktemp)"

# Using curl for streaming here as httpie seems to have issues actually live streaming this data back even though it has line breaks
set -o pipefail
curl \
  --fail-with-body \
  --show-error \
  --silent \
  --no-buffer \
  --header "X-Token: ${PAGELY_INTEGRATION_SECRET}" \
  --write-out "%{stderr}%{http_code}" \
  --request POST \
  --form "dest=${PAGELY_DEPLOY_DEST}" \
  --form 'file=@/tmp/deploy.tar.gz' \
  "${DEPLOY_URL}" 2>"${DEPLOY_HTTP_CODE_FILE}" | tee "${DEPLOY_OUTPUT}"
DEPLOY_CURL_EXIT_CODE=$?
DEPLOY_HTTP_RESP_CODE="$(cat "${DEPLOY_HTTP_CODE_FILE}")"

# Failure conditions
if [[ ${DEPLOY_CURL_EXIT_CODE} -ne 0 ]]; then
    echo "FAILURE in deploy request to: ${DEPLOY_URL}"
    if [[ -n "${DEPLOY_HTTP_RESP_CODE}" ]]; then
        echo "HTTP response code was: ${DEPLOY_HTTP_RESP_CODE}"
    fi
    exit 1
fi
if [[ "$(tail -n 1 "${DEPLOY_OUTPUT}")" == "FAILURE" ]]; then
    exit 1
fi
