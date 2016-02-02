#!/bin/bash
# @License EPL-1.0 <http://spdx.org/licenses/EPL-1.0>
##############################################################################
# Copyright (c) 2015 The Linux Foundation and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
##############################################################################

# Job will pass in a variable ${DATESTAMP} if this variable is false than we
# we are likely releasing a release candidate. We should skip closing the
# Nexus staging repository so that we can sign the artifacts.
SKIP_STAGING_CLOSE=false
# TODO: Figure out a solution to Open staging repos not being available
#       immediately. This means integration tests cannot reliably download and
#       test the new build if we leave the staging repo open.
# if [ "${DATESTAMP}" == "false" ]
# then
#     SKIP_STAGING_CLOSE=true
# fi

mkdir -p hide/from/pom/files
cd hide/from/pom/files
mkdir -p m2repo/org/opendaylight/

(IFS='
'
for m in `xmlstarlet sel -N x=http://maven.apache.org/POM/4.0.0 -t -m '//x:modules' -v '//x:module' ../../../../pom.xml`; do
    rsync -avz --exclude 'maven-metadata*' \
               --exclude '_remote.repositories' \
               --exclude 'resolver-status.properties' \
               "/tmp/r/org/opendaylight/$m" m2repo/org/opendaylight/
done)

# Add exception for integration project since they release under the
# integration top-level project.
rsync -avz --exclude 'maven-metadata*' \
           --exclude '_remote.repositories' \
           --exclude 'resolver-status.properties' \
           "/tmp/r/org/opendaylight/integration" m2repo/org/opendaylight/

mvn org.sonatype.plugins:nexus-staging-maven-plugin:1.6.2:deploy-staged-repository \
    -DskipStagingRepositoryClose=${SKIP_STAGING_CLOSE} \
    -DrepositoryDirectory="`pwd`/m2repo" \
    -DnexusUrl=http://nexus.opendaylight.org/ \
    -DstagingProfileId="425e43800fea70" \
    -DserverId="opendaylight.staging" \
    -s $SETTINGS_FILE \
    -gs $GLOBAL_SETTINGS_FILE | tee $WORKSPACE/deploy-staged-repository.log
