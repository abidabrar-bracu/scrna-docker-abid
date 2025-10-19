#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-}"
TARGET="${2:-ghcr}"   # ghcr | dockerhub | local
IMAGE_BASENAME="scanalysis-base"

if [[ -z "${VERSION}" ]]; then
  echo "Usage: $0 <version> [ghcr|dockerhub|local]"
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

# --- extract docs/version info ---
CID=$(docker create "$IMAGE")
mkdir -p docs
docker cp "$CID":/workspace/docs/python_versions.json docs/ || true
docker cp "$CID":/workspace/docs/R_versions.tsv docs/ || true
docker rm "$CID" >/dev/null
echo "📄 Version manifests copied into ./docs/"

# --- Update README.md with collapsible latest versions ---
PY_JSON="docs/python_versions.json"
R_TSV="docs/R_versions.tsv"
README="README.md"

# collapse tags
START_TAG="<!--VERSIONS_START-->"
END_TAG="<!--VERSIONS_END-->"

TMP_MD=$(mktemp)

{
  echo "${START_TAG}"
  echo ""
  echo "# Installed library versions (latest build)"
  echo ""
  echo "<details><summary><b>Python stack</b></summary>"
  echo ""
  echo '```text'
  jq -r 'to_entries | sort_by(.key)[] | "\(.key): \(.value)"' "${PY_JSON}" 2>/dev/null | column -t || echo "python_versions.json missing"
  echo '```'
  echo "</details>"
  echo ""
  echo "<details><summary><b>R stack</b></summary>"
  echo ""
  echo '```text'
  (column -t < "${R_TSV}" 2>/dev/null) || echo "R_versions.tsv missing"
  echo '```'
  echo "</details>"
  echo ""
  echo "${END_TAG}"
} > "${TMP_MD}"

if grep -q "${START_TAG}" "${README}"; then
  awk -v start="${START_TAG}" -v end="${END_TAG}" -v newfile="${TMP_MD}" '
    $0==start {f=1;system("cat " newfile);next}
    $0==end {f=0;next}
    !f
  ' "${README}" > "${README}.new" && mv "${README}.new" "${README}"
else
  cat "${TMP_MD}" >> "${README}"
fi


rm "${TMP_MD}"
echo "✅ README updated with latest package versions"