#!/bin/bash

# Echo how the script was called
echo "Called: $0 $*"

# Check if service name is provided. TYPE is optional and defaults to "agent" for
# backward compatibility with CI matrix steps that only pass the service name.
if [ $# -lt 1 ] || [ $# -gt 2 ]; then
    echo "Usage: $0 <service-name> [type]"
    echo "Available services are directories in the docker/ folder"
    echo "Available types: service | agent | mcp_server (default: agent)"
    exit 1
fi

SERVICE_NAME="$1"
TYPE="${2:-agent}"

# Convert hyphens to underscores for folder paths (repo uses underscores, Helm uses hyphens)
FOLDER_NAME="${SERVICE_NAME//-/_}"

# Move to project root
cd "$(dirname "$0")/.."

# Check for Dockerfile in src directory structure first, then fall back to docker directory
SRC_DOCKERFILE_PATH="src/agentic_platform/${TYPE}/${FOLDER_NAME}/Dockerfile"
DOCKER_DIR="docker/${FOLDER_NAME}"
DOCKER_DOCKERFILE_PATH="${DOCKER_DIR}/Dockerfile"

if [[ -f "$SRC_DOCKERFILE_PATH" ]]; then
    DOCKERFILE_PATH="$SRC_DOCKERFILE_PATH"
    echo "Using Dockerfile from src directory: $DOCKERFILE_PATH"
elif [[ -f "$DOCKER_DOCKERFILE_PATH" ]]; then
    DOCKERFILE_PATH="$DOCKER_DOCKERFILE_PATH"
    echo "Using Dockerfile from docker directory: $DOCKERFILE_PATH"
else
    echo "Error: Dockerfile not found at $SRC_DOCKERFILE_PATH or $DOCKER_DOCKERFILE_PATH"
    echo "Available services in docker/:"
    ls -1 docker/ 2>/dev/null | grep -v "^$" || echo "  No services found in docker/ directory"
    echo "Available services in src/agentic_platform/agent/:"
    ls -1 src/agentic_platform/agent/ 2>/dev/null | grep -v "^$" || echo "  No services found in src/agentic_platform/agent/ directory"
    exit 1
fi

# Configuration - handle both local and CI environments
if [[ -n "$AWS_REGION" ]]; then
    # Use environment variable (GitHub Actions)
    echo "Using AWS_REGION from environment: $AWS_REGION"
elif command -v aws &> /dev/null && aws configure get region &> /dev/null; then
    # Use AWS CLI config (local development)
    AWS_REGION=$(aws configure get region)
    echo "Using AWS_REGION from AWS CLI config: $AWS_REGION"
else
    # Default fallback
    AWS_REGION="us-east-1"
    echo "Using default AWS_REGION: $AWS_REGION"
fi

# Validate AWS_REGION is not empty
if [[ -z "$AWS_REGION" ]]; then
    echo "Error: AWS_REGION is empty"
    exit 1
fi

ECR_REPO_NAME="agentic-platform-${SERVICE_NAME}"  # Repository name based on service

# Build an immutable, traceable image tag.
#
# Order of precedence:
#   1. $IMAGE_TAG  (explicit override, e.g. CI passing v1.2.3)
#   2. $GITHUB_SHA (set by GitHub Actions, full commit SHA)
#   3. git rev-parse --short HEAD when run from a git checkout
#   4. timestamp fallback
#
# We always also push a moving "latest" alias so existing deploy tooling
# pointing at :latest keeps working, but :latest is no longer the only tag.
if [[ -n "$IMAGE_TAG" ]]; then
    PRIMARY_TAG="$IMAGE_TAG"
elif [[ -n "$GITHUB_SHA" ]]; then
    PRIMARY_TAG="${GITHUB_SHA}"
elif command -v git &> /dev/null && git rev-parse --short HEAD &> /dev/null; then
    PRIMARY_TAG="$(git rev-parse --short=12 HEAD)"
else
    PRIMARY_TAG="$(date -u +%Y%m%d%H%M%S)"
fi

echo "Primary image tag: $PRIMARY_TAG"

# Get AWS account ID - handle both local and CI
if command -v aws &> /dev/null; then
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
else
    echo "Error: AWS CLI not available"
    exit 1
fi

# Validate AWS_ACCOUNT_ID
if [[ -z "$AWS_ACCOUNT_ID" || "$AWS_ACCOUNT_ID" == "None" ]]; then
    echo "Error: Could not determine AWS Account ID"
    exit 1
fi

ECR_REPO_URI="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO_NAME"

echo "Configuration:"
echo "  AWS_REGION: $AWS_REGION"
echo "  AWS_ACCOUNT_ID: $AWS_ACCOUNT_ID"
echo "  ECR_REPO_NAME: $ECR_REPO_NAME"
echo "  ECR_REPO_URI: $ECR_REPO_URI"

# Authenticate Docker with ECR
echo "Authenticating with ECR..."
aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"

if [ $? -ne 0 ]; then
    echo "Error: Failed to authenticate with ECR"
    exit 1
fi

# Create ECR repository if it doesn't exist
echo "Ensuring ECR repository exists..."
if ! aws ecr describe-repositories --repository-names "$ECR_REPO_NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
    echo "Repository $ECR_REPO_NAME does not exist. Creating..."
    aws ecr create-repository --repository-name "$ECR_REPO_NAME" --region "$AWS_REGION"
    
    if [ $? -ne 0 ]; then
        echo "Error: Failed to create ECR repository"
        exit 1
    fi
    echo "Repository $ECR_REPO_NAME created successfully"
else
    echo "Repository $ECR_REPO_NAME already exists"
fi

# Build and push Docker image with both an immutable primary tag and a moving "latest".
echo "Building and pushing Docker image..."
docker buildx build \
    --platform linux/amd64,linux/arm64 \
    -t "$ECR_REPO_URI:$PRIMARY_TAG" \
    -t "$ECR_REPO_URI:latest" \
    -f "$DOCKERFILE_PATH" \
    --provenance=false \
    --push .

if [ $? -ne 0 ]; then
    echo "Error: Failed to push to ECR"
    exit 1
fi

echo "Done! Images pushed:"
echo "  $ECR_REPO_URI:$PRIMARY_TAG (immutable)"
echo "  $ECR_REPO_URI:latest      (moving alias)"

# Emit primary tag for downstream CI steps (k8s rollout, terraform vars, release notes).
if [[ -n "$GITHUB_OUTPUT" ]]; then
    {
        echo "image_uri=$ECR_REPO_URI:$PRIMARY_TAG"
        echo "image_tag=$PRIMARY_TAG"
    } >> "$GITHUB_OUTPUT"
fi