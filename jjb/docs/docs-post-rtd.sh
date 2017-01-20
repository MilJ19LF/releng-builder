#!/bin/bash
if [ $GERRIT_BRANCH == "master" ]; then
    RTD_BUILD_VERSION=latest
else
    RTD_BUILD_VERSION=${GERRIT_BRANCH/\//-}
fi
curl -X POST --data "version_slug=$RTD_BUILD_VERSION" https://readthedocs.org/build/{rtdproject}