#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-}"
TARGET="${2:-ghcr}"   # ghcr | dockerhub
IMAGE_BASENAME="scanalysis-base"

if [[ -z "${VERSION}" ]]; then
  echo "Usage: $0 <version> [ghcr|dockerhub]"
  exit 1
fi

if [[ "${TARGET}" == "dockerhub" ]]; then
  : "${DOCKERHUB_USER:?Set DOCKERHUB_USER}"
  IMAGE="${DOCKERHUB_USER}/${IMAGE_BASENAME}:${VERSION}"
  LATEST="${DOCKERHUB_USER}/${IMAGE_BASENAME}:latest"
  docker build -t "${IMAGE}" -t "${LATEST}" .
  docker push "${IMAGE}"
  docker push "${LATEST}"
  echo "✅ Pushed Docker Hub: ${IMAGE} and ${LATEST}"
elif [[ "${TARGET}" == "ghcr" ]]; then
  : "${GH_USER:?Set GH_USER}"
  IMAGE="ghcr.io/${GH_USER}/${IMAGE_BASENAME}:${VERSION}"
  LATEST="ghcr.io/${GH_USER}/${IMAGE_BASENAME}:latest"
  docker build -t "${IMAGE}" -t "${LATEST}" .
  docker push "${IMAGE}"
  docker push "${LATEST}"
  echo "✅ Pushed GHCR: ${IMAGE} and ${LATEST}"
elif [[ "${TARGET}" == "local" ]]; then
  IMAGE="${IMAGE_BASENAME}:${VERSION}"
  LATEST="${IMAGE_BASENAME}:latest"
  docker build -t "${IMAGE}" -t "${LATEST}" .
  echo "✅ Built locally: ${IMAGE} and ${LATEST}"
else
  echo "Unknown target: ${TARGET}"
  exit 1
fi
