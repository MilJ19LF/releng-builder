#!/bin/bash
git clone --depth 1 https://git.opendaylight.org/gerrit/releng/builder $WORKSPACE/.infra-scripts

virtualenv $WORKSPACE/.venv-openstack
source $WORKSPACE/.venv-openstack/bin/activate
pip install --upgrade pip
pip install --upgrade python-openstackclient python-heatclient
pip freeze

cd $WORKSPACE/.infra-scripts/openstack-hot

JOB_SUM=`echo $JOB_NAME | sum | awk '{{ print $1 }}'`
VM_NAME="$JOB_SUM-$BUILD_NUMBER"
openstack --os-cloud rackspace stack create --wait -t {stack-template} -e $WORKSPACE/opendaylight-infra-environment.yaml --parameter "job_name=$VM_NAME" --parameter "silo=$SILO" $STACK_NAME
OS_STATUS=`openstack --os-cloud rackspace stack show -f json -c stack_status $STACK_NAME | jq -r '.stack_status'`
if [ "$OS_STATUS" != "CREATE_COMPLETE" ]; then
    echo "Failed to initialize infrastructure. Quitting..."
    exit 1
fi
