#!/bin/bash

set -e

mkdir -p ./vendor/github.com/aws

SDK_MODEL_SOURCE=https://raw.githubusercontent.com/aws/aws-app-mesh-roadmap/main/appmesh-preview/sdk
SDK_VENDOR_PATH=./vendor/github.com/aws/aws-sdk-go
API_VERSION=2019-01-25
API_PATH=$SDK_VENDOR_PATH/models/apis/appmesh/$API_VERSION
SERVICE_NAME=$([ "$APPMESH_PREVIEW" == "y" ] && echo "appmesh-preview" || echo "appmesh" )

# Clone the SDK to the vendor path (removing an old one if necessary)
rm -rf $SDK_VENDOR_PATH
git clone --depth 1 https://github.com/aws/aws-sdk-go.git $SDK_VENDOR_PATH

# Override the SDK models for App Mesh
curl -s $SDK_MODEL_SOURCE/api.json |\
    # Always use the "vanilla" flavors of UID, Service ID, and Service Name.
    # This ensures the SDK we generate is always the same interface objects, only changing
    # the endpoint and signing name when using preview.
    jq "(.metadata.uid) |= \"appmesh-$API_VERSION\"" |\
    jq "(.metadata.serviceId) |= \"App Mesh\"" |\
    jq "(.metadata.serviceFullName) |= \"AWS App Mesh\"" |\
    # Set the endpoint prefix and signing name to the desired value, based on
    # whether or not we're using the preview endpoint
    jq "(.metadata | .endpointPrefix, .signingName) |= \"$SERVICE_NAME\"" \
    > $API_PATH/api-2.json
curl -s $SDK_MODEL_SOURCE/docs.json > $API_PATH/docs-2.json
curl -s $SDK_MODEL_SOURCE/examples.json > $API_PATH/examples-1.json
curl -s $SDK_MODEL_SOURCE/paginators.json > $API_PATH/paginators-1.json

# Generate the SDK
pushd ./vendor/github.com/aws/aws-sdk-go
make generate
popd

# Use the vendored version of aws-sdk-go
go mod edit -replace github.com/aws/aws-sdk-go=./vendor/github.com/aws/aws-sdk-go
go mod tidy
