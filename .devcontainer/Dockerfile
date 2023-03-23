# For details, see https://github.com/devcontainers/images/tree/main/src/go
FROM mcr.microsoft.com/devcontainers/go:0-1.20

RUN echo "Installing ko..." \
    && go install github.com/google/ko@latest \
    echo "Installing protoc-gen-gofast..." \
    && go get github.com/gogo/protobuf/protoc-gen-gofast

RUN echo "Downloading protobuf..." \
    && curl -sSL -H "Accept: application/vnd.github.v3+json" "https://api.github.com/repos/protocolbuffers/protobuf/tags" -o /tmp/tags.json \
    && VERSION_LIST="$(jq -r '.[] | select(.name | contains("rc") | not) | .name | split("v") | .[1]' /tmp/tags.json | tr -d '"' | sort -rV)" \
    && PROTOBUF_LATEST_VERSION="$(echo "${VERSION_LIST}" | head -n 1)" \
    && PROTOBUF_FILE_NAME="protoc-${PROTOBUF_LATEST_VERSION}-linux-$(uname -m)" \
    && curl -fsSLO "https://github.com/protocolbuffers/protobuf/releases/download/v${PROTOBUF_LATEST_VERSION}/${PROTOBUF_FILE_NAME}.zip" \
    && sudo unzip "${PROTOBUF_FILE_NAME}.zip" -d /usr/local/protoc \
    && rm "${PROTOBUF_FILE_NAME}.zip" \

ENV PATH ${PATH}:/usr/local/protoc/bin
