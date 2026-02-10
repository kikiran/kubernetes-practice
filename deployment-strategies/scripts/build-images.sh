#!/bin/bash

# Script to build and push Docker images for deployment strategies demo
# Usage: ./build-images.sh <registry> <version>

set -e

REGISTRY=${1:-"your-registry"}
VERSION=${2:-"v1"}
COLOR=${3:-"blue"}

echo "========================================="
echo "Building Docker Image"
echo "========================================="
echo "Registry: $REGISTRY"
echo "Version: $VERSION"
echo "Color: $COLOR"
echo "========================================="

# Build image
echo "Building image..."
docker build \
    --build-arg APP_VERSION=$VERSION \
    --build-arg APP_COLOR=$COLOR \
    -t $REGISTRY/deployment-demo:$VERSION \
    -t $REGISTRY/deployment-demo:latest \
    .

echo "✅ Image built successfully!"

# Show image
docker images | grep deployment-demo

# Push to registry
echo ""
read -p "Push to registry? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
    echo "Logging in to Docker registry..."
    docker login $REGISTRY
    
    echo "Pushing image..."
    docker push $REGISTRY/deployment-demo:$VERSION
    
    if [ "$VERSION" == "latest" ] || [ "$4" == "--push-latest" ]; then
        docker push $REGISTRY/deployment-demo:latest
    fi
    
    echo "✅ Image pushed successfully!"
    echo "Image: $REGISTRY/deployment-demo:$VERSION"
fi

echo ""
echo "========================================="
echo "Build Complete!"
echo "========================================="
echo "Image: $REGISTRY/deployment-demo:$VERSION"
echo "To use in Kubernetes, update manifests with:"
echo "  image: $REGISTRY/deployment-demo:$VERSION"
echo "========================================="
