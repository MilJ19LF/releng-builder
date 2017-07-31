#!/bin/bash
# SPDX-License-Identifier: EPL-1.0
##############################################################################
# Copyright (c) 2017 The Linux Foundation and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
##############################################################################

YAML_FILE="${WORKSPACE}/jjb/autorelease/validate-autorelease-${STREAM}.yaml"
BRANCH="stable/${STREAM}"

# The current development release will not have a stable branch defined so if
# branch does not exist assume master
wget --no-verbose -O /tmp/ar-branches.json https://git.opendaylight.org/gerrit/projects/releng%2Fautorelease/branches/
if ! grep "$BRANCH" /tmp/ar-branches.json; then
    BRANCH=master
fi

wget --no-verbose -O /tmp/pom.xml "https://git.opendaylight.org/gerrit/gitweb?p=releng/autorelease.git;a=blob_plain;f=pom.xml;hb=$GERRIT_BRANCH"
modules=($(xmlstarlet sel -N x=http://maven.apache.org/POM/4.0.0 -t -m '//x:modules' -v '//x:module' /tmp/pom.xml))

cat > "$YAML_FILE" << EOF
---
# Autogenerated by autorelease autorelease-update-validate-autorelease-jobs-{stream} Jenkins job
- project:
    name: autorelease-validate-${STREAM}
    jobs:
      - '{project-name}-validate-autorelease-{stream}'
    stream: ${STREAM}
    branch: ${BRANCH}
    project-name:
EOF

for module in "${modules[@]}"; do
    echo "Include $module"
    echo "      - ${module//\//-}:" >> "$YAML_FILE"
    echo "          project: $module" >> "$YAML_FILE"
done

git add "${YAML_FILE}"