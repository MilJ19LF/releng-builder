#!/bin/bash

# Options:
#   -x: Echo commands
#   -e: Fail on errors
#   -o pipefail: Fail on errors in scripts this calls, give stacktrace
set -ex -o pipefail

# Install required packages
virtualenv rpm_build
# shellcheck disable=SC1091
source rpm_build/bin/activate
PYTHON="rpm_build/bin/python"
$PYTHON -m pip install --upgrade pip
$PYTHON -m pip install -r "$WORKSPACE/packaging/packages/requirements.txt"

# Verify artifact at DOWNLOAD_URL exists
# shellcheck disable=SC2154
url_status=$(curl --silent --head --location --output /dev/null --write-out \
  '%{http_code}' "$DOWNLOAD_URL")
if [[ $url_status = 2* ]]; then
  echo "Artifact at DOWNLOAD_URL exists"
else
  echo "Artifact at DOWNLOAD_URL does not exist"
  exit 1
fi


# Packaging logic needs a tarball, but can repackage a zip into tar.gz
# if needed. All builds except multipatch-test publish both a tar.gz and zip.
# Autorelease passes DOWNLOAD_URL to zip, others typically use tar.gz.
# If URL is to zip, check if there's a tar.gz available to avoid repackaging.
if [[ $DOWNLOAD_URL = *.zip ]]; then
  # shellcheck disable=SC2154
  candidate_tarball_url="${DOWNLOAD_URL//zip/tar.gz}"
  # shellcheck disable=SC2154
  url_status=$(curl --silent --head --location --output /dev/null --write-out \
    '%{http_code}' "$candidate_tarball_url")
  if [[ $url_status = 2* ]]; then
    DOWNLOAD_URL="$candidate_tarball_url"
  fi
fi

# Build release specified by build params
"$WORKSPACE/packaging/packages/build.py" --rpm \
                                         --changelog_name "$CHANGELOG_NAME" \
                                         --changelog_email "$CHANGELOG_EMAIL" \
                                         direct \
                                         --download_url "$DOWNLOAD_URL" \
                                         --pkg_version "$PKG_VERSION_OVERRIDE"

# Always allow push to scratch repos, only push to CD repos in RelEng Jenkins
if [ "$DEPLOY_TO_REPO" == "opendaylight-epel-7-x86_64-devel" ]; then
  # Move RPMs (SRPM and noarch) to dir of files that will be uploaded to Nexus
  UPLOAD_FILES_PATH="$WORKSPACE/upload_files"
  mkdir -p "$UPLOAD_FILES_PATH"
  cp "$HOME/rpmbuild/RPMS/noarch/"*.rpm "$_"
  cp "$HOME/rpmbuild/SRPMS/"*.rpm "$_"
else
  # Publish RPMs to CD repos if in production Jenkins, not in sandbox Jenkins
  if [ "$SILO" == "sandbox" ]; then
    echo "Not uploading RPMs to Nexus because running in sandbox"
  elif  [ "$SILO" == "releng" ]; then
    # Move RPMs (SRPM+noarch) to dir of files that will be uploaded to Nexus
    UPLOAD_FILES_PATH="$WORKSPACE/upload_files"
    mkdir -p "$UPLOAD_FILES_PATH"
    cp "$HOME/rpmbuild/RPMS/noarch/"*.rpm "$_"
    cp "$HOME/rpmbuild/SRPMS/"*.rpm "$_"
  else
    echo "Unknown Jenkins silo: $SILO"
    exit 1
  fi
fi
