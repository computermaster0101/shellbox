#!/bin/bash -x
##
## Install Tomcat 8 and place into /opt/tomcat8.
##
set -o errexit -o nounset -o pipefail

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

## Test to ensure we have java - if not install it. :)
command -v java >/dev/null 2>&1 || { echo "Java Required but it's not installed.  Aborting." >&2; exit 1; }

## install some general functions
source ${CURRENT_DIR}/utilities.sh

function -h {
cat <<USAGE
USAGE: installTomcat.sh     (--minorBugVersion "0.30")?
                            (--majorVersion "8")?
                            (--jvmArgs "-server -Xmx2048M -Xms2048M -XX:+UseConcMarkSweepGC -XX:+AggressiveOpts -Djava.rmi.server.hostname=localhost -Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.port=6969 -Dcom.sun.management.jmxremote.ssl=false  -Dcom.sun.management.jmxremote.authenticate=false")?
                            (--shutdownPort "8005")?
                            (--httpPort "8080")?
                            (--httpProtocol "org.apache.coyote.http11.Http11NioProtocol")?
                            (--sslPort "8443")?
                            (--ajpPort "8009")?
                            (--unpackWars true)?
                            (--autoDeploy true)?

  Install and configure Tomcat.

USAGE
}; function --help { -h ;}

function options {
  while [[ ${1:+isset} ]]
  do
    case "$1" in
      --minorBugVersion)    minorBugVersion="$2"     ; shift ;;
      --majorVersion)       majorVersion="$2"        ; shift ;;
      --jvmArgs)            jvmArgs="$2"             ; shift ;;
      --shutdownPort)       shutdownPort="$2"        ; shift ;;
      --httpPort)           httpPort="$2"            ; shift ;;
      --httpProtocol)       httpProtocol="$2"        ; shift ;;
      --sslPort)            sslPort="$2"             ; shift ;;
      --ajpPort)            ajpPort="$2"             ; shift ;;
      --unpackWars)         unpackWars="$2"          ; shift ;;
      --autoDeploy)         autoDeploy="$2"          ; shift ;;
      --*)                  err "No such option: $1" ;;
    esac
    shift
  done
}

function install_tomcat {
    echo "Installing Tomcat ${majorVersion}... "
    ## tomcat home
    user="tomcat${majorVersion}"
    export CATALINA_HOME=/opt/tomcat${majorVersion}
    sudo mkdir -p ${CATALINA_HOME}

    ## only add if user doesn't exist
    if [ ! -d /home/tomcat8 ]; then
        ## make a tomcat user
        sudo useradd -m ${user}
        ## lock the tomcat user from remote logins
        sudo passwd -l ${user}
    fi

    ## ensure we have the tomcat home env variable set
    sudo touch /etc/environment
    echo "CATALINA_HOME=\"${CATALINA_HOME}\"" | sudo tee -a /etc/environment

    ## go to directory for downloading.
    cd /opt/

    sudo wget http://mirror.cogentco.com/pub/apache/tomcat/tomcat-${majorVersion}/v${majorVersion}.${minorBugVersion}/bin/apache-tomcat-${majorVersion}.${minorBugVersion}.tar.gz
    sudo wget https://www.apache.org/dist/tomcat/tomcat-${majorVersion}/v${majorVersion}.${minorBugVersion}/bin/apache-tomcat-${majorVersion}.${minorBugVersion}.tar.gz.md5

    sudo md5sum -c apache-tomcat-${majorVersion}.${minorBugVersion}.tar.gz.md5
    mdTomcatPassed=$?
    if [ ${mdTomcatPassed} -eq 1  ]; then
        echo "md5sum failed for tomcat archive."
        exit 1
    fi

    sudo wget http://mirror.cogentco.com/pub/apache/tomcat/tomcat-${majorVersion}/v${majorVersion}.${minorBugVersion}/bin/extras/catalina-jmx-remote.jar
    sudo wget https://www.apache.org/dist/tomcat/tomcat-${majorVersion}/v${majorVersion}.${minorBugVersion}/bin/extras/catalina-jmx-remote.jar.md5

    sudo md5sum -c catalina-jmx-remote.jar.md5
    mdJMXPassed=$?
    if [ ${mdJMXPassed} -eq 1 ]; then
        echo "md5sum failed for jmx-remote jar."
        exit 1
    fi

    sudo tar xvzf apache-tomcat-${majorVersion}.${minorBugVersion}.tar.gz
    sudo mv apache-tomcat-${majorVersion}.${minorBugVersion}/** ${CATALINA_HOME}
    sudo mv catalina-jmx-remote.jar ${CATALINA_HOME}/lib/

    sudo touch ${CATALINA_HOME}/conf/server.xml
    sudo su <<HERE
cat <<EOF > ${CATALINA_HOME}/conf/server.xml
<?xml version='1.0' encoding='utf-8'?>
<Server port="${shutdownPort}" shutdown="SHUTDOWN">
    <Listener className="org.apache.catalina.startup.VersionLoggerListener" />
    <Listener className="org.apache.catalina.core.AprLifecycleListener" SSLEngine="on" />
    <Listener className="org.apache.catalina.core.JreMemoryLeakPreventionListener" />
    <Listener className="org.apache.catalina.mbeans.GlobalResourcesLifecycleListener" />
    <Listener className="org.apache.catalina.core.ThreadLocalLeakPreventionListener" />

    <GlobalNamingResources>
        <Resource name="UserDatabase" auth="Container"
                  type="org.apache.catalina.UserDatabase"
                  description="User database that can be updated and saved"
                  factory="org.apache.catalina.users.MemoryUserDatabaseFactory"
                  pathname="conf/tomcat-users.xml" />
    </GlobalNamingResources>

    <Service name="Catalina">

        <Connector port="${httpPort}"
              protocol="${httpProtocol}"
              connectionTimeout="20000"
              URIEncoding="UTF-8"
              redirectPort="${sslPort}" />

        <Connector port="${ajpPort}"
              protocol="AJP/1.3"
              redirectPort="${sslPort}" />

      <Engine name="Catalina" defaultHost="localhost">

        <Valve className="org.apache.catalina.valves.RemoteIpValve"
              remoteIpHeader="x-forwarded-for"
              portHeader="x-forwarded-port"
              protocolHeader="x-forwarded-proto"/>

        <Realm className="org.apache.catalina.realm.LockOutRealm">
        <Realm className="org.apache.catalina.realm.UserDatabaseRealm"
              resourceName="UserDatabase"/>
        </Realm>

        <Host name="localhost"  appBase="webapps"
              unpackWARs="${unpackWars}"
              autoDeploy="${autoDeploy}">

            <Valve className="org.apache.catalina.valves.AccessLogValve" directory="logs"
                prefix="localhost_access_log." suffix=".txt"
                pattern="%h %l %u %t &quot;%r&quot; %s %b" />

        </Host>
      </Engine>
    </Service>
</Server>
EOF
HERE

    ## remove unneeded items
    sudo rm -r ${CATALINA_HOME}/webapps/docs
    sudo rm -r ${CATALINA_HOME}/webapps/examples
    sudo rm -r ${CATALINA_HOME}/webapps/host-manager
    sudo rm -r ${CATALINA_HOME}/webapps/manager
    sudo rm -r ${CATALINA_HOME}/webapps/ROOT

    sudo touch ${CATALINA_HOME}/bin/supervisor-wrapper.sh
    sudo su <<HERE
cat <<EOF > ${CATALINA_HOME}/bin/supervisor-wrapper.sh
#!/bin/bash
# Source: http://serverfault.com/questions/425132/controlling-tomcat-with-supervisor
function shutdown() {
    date
    echo "Shutting down Tomcat"
    unset CATALINA_PID # Necessary in some cases
    \$CATALINA_HOME/bin/catalina.sh stop
}

date
echo "Starting Tomcat"
export CATALINA_OPTS="${jvmArgs}"
export CATALINA_HOME="${CATALINA_HOME}"
export CATALINA_BASE="${CATALINA_HOME}"
export CATALINA_PID=/tmp/\$$
export TOMCAT_USER="${user}"
export TOMCAT_GROUP="${user}"

. \$CATALINA_HOME/bin/catalina.sh start

# Allow any signal which would kill a process to stop Tomcat
trap shutdown HUP INT QUIT ABRT KILL ALRM TERM TSTP

echo "Waiting for \`cat \$CATALINA_PID\`"
wait \`cat \$CATALINA_PID\`
EOF
HERE

    sudo chmod +x ${CATALINA_HOME}/bin/supervisor-wrapper.sh

    ## ensure proper permissions
    sudo chown -R ${user}:${user} ${CATALINA_HOME}
    sudo chmod -R g+rwX ${CATALINA_HOME}

    cd ${CURRENT_DIR}
    sudo bash ./installSupervisordConfig.sh --name "${user}" --toexecute "${CATALINA_HOME}/bin/supervisor-wrapper.sh" --serviceuser "${user}" --directory "${CATALINA_HOME}" --startsecs "120"
}

function validateopts {
    if [ -z ${minorBugVersion+x} ]; then
        minorBugVersion="0.32"
        echo "** minorBugVersion not set, using default --> ${minorBugVersion}"
    fi
    if [ -z ${majorVersion+x} ]; then
        majorVersion="8"
        echo "** majorVersion not set, using default --> ${majorVersion}"
    fi
    if [ -z ${jvmArgs+x} ]; then
        jvmArgs="-server -Xmx2048M -Xms2048M -XX:+UseConcMarkSweepGC -XX:+AggressiveOpts -Djava.rmi.server.hostname=localhost -Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.port=6969 -Dcom.sun.management.jmxremote.ssl=false  -Dcom.sun.management.jmxremote.authenticate=false"
        echo "** jvmArgs not set, using default --> ${jvmArgs}"
    fi
    if [ -z ${shutdownPort+x} ]; then
        shutdownPort="8005"
        echo "** shutdownPort not set, using default --> ${shutdownPort}"
    fi
    if [ -z ${httpPort+x} ]; then
        httpPort="8080"
        echo "** httpPort not set, using default --> ${httpPort}"
    fi
    if [ -z ${httpProtocol+x} ]; then
        httpProtocol="org.apache.coyote.http11.Http11NioProtocol"
        echo "** httpProtocol not set, using default --> ${httpProtocol}"
    fi
    if [ -z ${sslPort+x} ]; then
        sslPort="8443"
        echo "** sslPort not set, using default --> ${sslPort}"
    fi
    if [ -z ${ajpPort+x} ]; then
        ajpPort="8009"
        echo "** ajpPort not set, using default --> ${ajpPort}"
    fi
    if [ -z ${unpackWars+x} ]; then
        unpackWars=true
        echo "** unpackWars not set, using default --> ${unpackWars}"
    fi
    if [ -z ${autoDeploy+x} ]; then
        autoDeploy=true
        echo "** autoDeploy not set, using default --> ${autoDeploy}"
    fi
}

function main {
  options "$@"
  validateopts
  install_tomcat
}

if [[ ${1:-} ]] && declare -F | cut -d' ' -f3 | fgrep -qx -- "${1:-}"
then "$@"
else main "$@"
fi
