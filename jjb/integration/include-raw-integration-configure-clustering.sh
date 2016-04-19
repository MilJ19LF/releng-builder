echo "#################################################"
echo "##         Configure Cluster and Start         ##"
echo "#################################################"

AKKACONF=/tmp/${BUNDLEFOLDER}/configuration/initial/akka.conf
MODULESCONF=/tmp/${BUNDLEFOLDER}/configuration/initial/modules.conf
MODULESHARDSCONF=/tmp/${BUNDLEFOLDER}/configuration/initial/module-shards.conf
CONTROLLERMEM="2048m"

if [ ${CONTROLLERSCOPE} == 'all' ]; then
    ACTUALFEATURES="odl-integration-compatible-with-all,${CONTROLLERFEATURES}"
    CONTROLLERMEM="3072m"
else
    ACTUALFEATURES="${CONTROLLERFEATURES}"
fi
# Some versions of jenkins job builder result in feature list containing spaces
# and ending in newline. Remove all that.
ACTUALFEATURES=`echo "${ACTUALFEATURES}" | tr -d '\n \r'`

# Utility function for joining strings.
function join {
    delim=' '
    final=$1; shift

    for str in $* ; do
        final=${final}${delim}${str}
    done

    echo ${final}
}

# Create the string for nodes
for i in `seq 1 ${NUM_ODL_SYSTEM}` ; do
    CONTROLLERIP=ODL_SYSTEM_${i}_IP
    nodes[$i]=${!CONTROLLERIP}
done

nodes_list=$(join ${nodes[@]})

echo ${nodes_list}

# Run script plan in case it exists
if [ -f ${WORKSPACE}/test/csit/scriptplans/${TESTPLAN} ]; then
    echo "scriptplan exists!!!"
    echo "Changing the scriptplan path..."
    cat ${WORKSPACE}/test/csit/scriptplans/${TESTPLAN} | sed "s:integration:${WORKSPACE}:" > scriptplan.txt
    cat scriptplan.txt
    for line in $( egrep -v '(^[[:space:]]*#|^[[:space:]]*$)' scriptplan.txt ); do
        echo "Executing ${line}..."
        source ${line}
    done
fi

# Create the configuration script to be run on controllers.
cat > ${WORKSPACE}/configuration-script.sh <<EOF

echo "Changing to /tmp"
cd /tmp

echo "Downloading the distribution from ${ACTUALBUNDLEURL}"
wget --no-verbose  '${ACTUALBUNDLEURL}'

echo "Extracting the new controller..."
unzip -q ${BUNDLE}

echo "Configuring the startup features..."
FEATURESCONF=/tmp/${BUNDLEFOLDER}/etc/org.apache.karaf.features.cfg
sed -ie "s/featuresBoot=.*/featuresBoot=config,standard,region,package,kar,ssh,management,${ACTUALFEATURES}/g" \${FEATURESCONF}
sed -ie "s%mvn:org.opendaylight.integration/features-integration-index/${BUNDLEVERSION}/xml/features%mvn:org.opendaylight.integration/features-integration-index/${BUNDLEVERSION}/xml/features,mvn:org.opendaylight.integration/features-integration-test/${BUNDLEVERSION}/xml/features%g" \${FEATURESCONF}
cat \${FEATURESCONF}

echo "Configuring the log..."
LOGCONF=/tmp/${BUNDLEFOLDER}/etc/org.ops4j.pax.logging.cfg
sed -ie 's/log4j.appender.out.maxBackupIndex=10/log4j.appender.out.maxBackupIndex=1/g' \${LOGCONF}
# FIXME: Make log size limit configurable from build parameter.
sed -ie 's/log4j.appender.out.maxFileSize=1MB/log4j.appender.out.maxFileSize=100GB/g' \${LOGCONF}
cat \${LOGCONF}

echo "Configure java home and max memory..."
MEMCONF=/tmp/${BUNDLEFOLDER}/bin/setenv
sed -ie 's%^# export JAVA_HOME%export JAVA_HOME="\${JAVA_HOME:-${JAVA_HOME}}"%g' \${MEMCONF}
sed -ie 's/JAVA_MAX_MEM="2048m"/JAVA_MAX_MEM="${CONTROLLERMEM}"/g' \${MEMCONF}
cat \${MEMCONF}

echo "Set Java version"
sudo /usr/sbin/alternatives --install /usr/bin/java java ${JAVA_HOME}/bin/java 1
sudo /usr/sbin/alternatives --set java ${JAVA_HOME}/bin/java
echo "JDK default version ..."
java -version

echo "Set JAVA_HOME"
export JAVA_HOME="${JAVA_HOME}"
# Did you know that in HERE documents, single quote is an ordinary character, but backticks are still executing?
JAVA_RESOLVED=\`readlink -e "\${JAVA_HOME}/bin/java"\`
echo "Java binary pointed at by JAVA_HOME: \${JAVA_RESOLVED}"

# Copy shard file if exists
if [ -f /tmp/custom_shard_config.txt ]; then
    echo "Custom shard config exists!!!"
    echo "Copying the shard config..."
    cp /tmp/custom_shard_config.txt /tmp/${BUNDLEFOLDER}/bin/
fi

echo "Configuring cluster"
/tmp/${BUNDLEFOLDER}/bin/configure_cluster.sh \$1 ${nodes_list}

echo "Dump akka.conf"
cat ${AKKACONF}

echo "Dump modules.conf"
cat ${MODULESCONF}

echo "Dump module-shards.conf"
cat ${MODULESHARDSCONF}

echo "Starting controller..."
/tmp/${BUNDLEFOLDER}/bin/start

EOF

# Copy over the configuration script and configuration files to each controller
# Execute the configuration script on each controller.
for i in `seq 1 ${NUM_ODL_SYSTEM}`
do
    CONTROLLERIP=ODL_SYSTEM_${i}_IP
    echo "Configuring member-${i} with IP address ${!CONTROLLERIP}"
    scp ${WORKSPACE}/configuration-script.sh ${!CONTROLLERIP}:/tmp/
    ssh ${!CONTROLLERIP} "bash /tmp/configuration-script.sh ${i}"
done

# vim: ts=4 sw=4 sts=4 et ft=sh :
