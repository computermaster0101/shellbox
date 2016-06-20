#!/bin/bash
##
## Installation script for Apache User Grid EC2 Cluster.
##
## Some really good, general, instructions.
## https://groups.google.com/forum/#!topic/usergrid/PMTWd16oPVk
## and more specific for ubuntu 14
## http://foorious.com/devops/usergrid/install-trusty/build/
##
set -o errexit -o nounset -o pipefail

# a few goabls.
CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
USER_GRID_SOURCE=/opt/source/
USER_GRID_HOME=/opt/usergrid
USER_GRID_PROPERTIES_FILE=${USER_GRID_HOME}/usergrid-custom-standalone.properties

## Test to ensure we have java - if not install it. :)
command -v java >/dev/null 2>&1 || { echo "Java Required but it's not installed.  Aborting." >&2; exit 1; }
# Test to ensure we have supervisor - install it.
command -v supervisord >/dev/null 2>&1 || { echo "Supervisor is Required but it's not installed.  Aborting." >&2; exit 1; }


## "install" some general functions
source ${CURRENT_DIR}/utilities.sh

function -h {
cat <<USAGE
 USAGE: mesosflexinstall (--rel <mesos-version>)?
                         (--slave-hostname <SLAVE_HOSTNAME>)?

  Install and configure User Grid.

USAGE
}; function --help { -h ;}

function options {
  while [[ ${1:+isset} ]]
  do
    case "$1" in
      --cassandraHosts)                     cassandraHosts="$2"                     ; shift ;;
      --cassandraUsername)                  cassandraUsername="$2"                  ; shift ;;
      --cassandraPassword)                  cassandraPassword="$2"                  ; shift ;;
      --mailTransportProtocol)              mailTransportProtocol="$2"              ; shift ;;
      --mailServerHost)                     mailServerHost="$2"                     ; shift ;;
      --mailServerPort)                     mailServerPort="$2"                     ; shift ;;
      --mailHost)                           mailHost="$2"                           ; shift ;;
      --mailPort)                           mailPort="$2"                           ; shift ;;
      --mailAuth)                           mailAuth="$2"                           ; shift ;;
      --mailQuitWait)                       mailQuitWait="$2"                       ; shift ;;
      --mailAuthUsername)                   mailAuthUsername="$2"                   ; shift ;;
      --mailAuthPassword)                   mailAuthPassword="$2"                   ; shift ;;
      --cassKeyspaceStrategy)               cassKeyspaceStrategy="$2"               ; shift ;;
      --cassStrategyReplicationFactor)      cassStrategyReplicationFactor="$2"      ; shift ;;
      --cassNumberOfConnectionsPerHost)     cassNumberOfConnectionsPerHost="$2"     ; shift ;;
      --cassClusterName)                    cassClusterName="$2"                    ; shift ;;
      --cassWriteConsistencyLevel)          cassWriteConsistencyLevel="$2"          ; shift ;;
      --cassReadConsistencyLevel)           cassReadConsistencyLevel="$2"           ; shift ;;
      --cassKeyspaceStrategyOptions)        cassKeyspaceStrategyOptions="$2"        ; shift ;;
      --sysadminLoginName)                  sysadminLoginName="$2"                  ; shift ;;
      --sysadminLoginEmail)                 sysadminLoginEmail="$2"                 ; shift ;;
      --sysadminLoginPassword)              sysadminLoginPassword="$2"              ; shift ;;
      --sysadminEmail)                      sysadminEmail="$2"                      ; shift ;;
      --sysadminLoginAllowed)               sysadminLoginAllowed="$2"               ; shift ;;
      --sysadminApproveUsers)               sysadminApproveUsers="$2"               ; shift ;;
      --managementMailerEmail)              managementMailerEmail="$2"              ; shift ;;
      --userGridLoadBalancerUrl)            userGridLoadBalancerUrl="$2"            ; shift ;;
      --adminUsersRequireConfirmation)      adminUsersRequireConfirmation="$2"      ; shift ;;
      --adminUsersRequireActivation)        adminUsersRequireActivation="$2"        ; shift ;;
      --notifyAdminOfActivation)            notifyAdminOfActivation="$2"            ; shift ;;
      --orgsRequireConfirmation)            orgsRequireConfirmation="$2"            ; shift ;;
      --orgsRequireActivation)              orgsRequireActivation="$2"              ; shift ;;
      --notifySysAdminOnNewOrgs)            notifySysAdminOnNewOrgs="$2"            ; shift ;;
      --notifySysAdminOnNewAdmins)          notifySysAdminOnNewAdmins="$2"          ; shift ;;
      --awsAccessKey)                       awsAccessKey="$2"                       ; shift ;;
      --awsSecretKey)                       awsSecretKey="$2"                       ; shift ;;
      --s3AssetsBucket)                     s3AssetsBucket="$2"                     ; shift ;;
      --counterBatchSize)                   counterBatchSize="$2"                   ; shift ;;
      --counterBatchInterval)               counterBatchInterval="$2"               ; shift ;;
      --counterSkipAggregate)               counterSkipAggregate="$2"               ; shift ;;
      --schedulerEnabled)                   schedulerEnabled="$2"                   ; shift ;;
      --schedulerTimeout)                   schedulerTimeout="$2"                   ; shift ;;
      --schedulerQueueName)                 schedulerQueueName="$2"                 ; shift ;;
      --schedulerNumberWorkers)             schedulerNumberWorkers="$2"             ; shift ;;
      --schedulerIntervalMills)             schedulerIntervalMills="$2"             ; shift ;;
      --schedulerMaxFail)                   schedulerMaxFail="$2"                   ; shift ;;
      --installType)                        installType="$2"                        ; shift ;;
      --initUserGrid)                       initUserGrid="$2"                       ; shift ;;
      --jvmArgs)                            jvmArgs="$2"                            ; shift ;;
      --*)                                  err "No such option: $1" ;;
    esac
    shift
  done
}

function install_usergrid {

    ## install needed checkout/build deps.
    apt-get update -y
    apt-get install -y curl git maven jq #ruby-full

    mkdir -p ${USER_GRID_SOURCE}
    mkdir -p ${USER_GRID_HOME}
    cd ${USER_GRID_SOURCE}

    git clone -b 1.0.1 https://github.com/MindsIgnited/incubator-usergrid.git

    ## setup configurations first
    touch ${USER_GRID_PROPERTIES_FILE}
    config_users # always need to do the users.
    if [ "${installType}" == "local" ]; then
        ## perform local installation - dev/testing env easy and quick install.
        echo "Installing for a dev/testing environment, quick and simple setup. "
        config_local
    elif [ "${installType}" == "advanced" ]; then
        echo "Installing peicemeal install. Advanced - you have to know exactly what you want."
        echo "right now not implemented, don't have time but this would be a good addition but needs to be succinct."
        exit 1
    else
        echo "Installing for production, will used defaults for options not configured manually."
#        config_mail
#        config_schedulers
        disable_counters
        disable_schedulers
#
        config_url_mappings  ## we will not get any emails but setting this just in case.
        config_notifications ## by default they are all disabled.
        config_cassandra_host
        config_cassandra
    fi

    ## build and install User Grid
    cd incubator-usergrid/stack/
    mvn clean package -DskipTests=true
    cp ${USER_GRID_SOURCE}/incubator-usergrid/stack/launcher/target/usergrid-launcher-*-SNAPSHOT.jar ${USER_GRID_HOME}/usergrid-launcher.jar

    ## build and install User Grid CLI - just in case.
#    cd ../ugc/
#    gem install ugc

    ## ensure proper permissions
    chgrp -R ubuntu ${USER_GRID_HOME}
    chown -R ubuntu ${USER_GRID_HOME}
    chmod -R g+rwX ${USER_GRID_HOME}

    ${CURRENT_DIR}/install-supervisordConfig.sh --name="usergrid" --toexecute="java ${jvmArgs} -jar ${USER_GRID_HOME}/usergrid-launcher.jar -nogui -init"
    sleep 10
    # non standard config
    echo "directory=${USER_GRID_HOME}" >> /etc/supervisor/conf.d/usergrid.conf
    service supervisor stop
    sleep 10
    service supervisor start
    service supervisor start ## doesn't seem to always restart properly!?!

    ## wait for a few - then run the curl commands to setup instance.
    ## use cloud for the first org and default for the app
    if [ "${initUserGrid}" == "true" ]; then
        sleep 60
        echo "Performing User Grid initialization... "
        curl -u "${sysadminLoginName}:${sysadminLoginPassword}" -XGET "http://localhost:8080/system/database/setup"
        curl -u "${sysadminLoginName}:${sysadminLoginPassword}" -XGET "http://localhost:8080/system/superuser/setup"
        curl -XPOST  -d 'organization=default&username=admin&name=Admin&email=admin@test.com&password=admin' http://localhost:8080/management/organizations
        token=($(curl -XGET 'http://localhost:8080/management/token?grant_type=password&username=admin&password=admin' | jq -r '.access_token'))
        curl -H "Authorization: Bearer ${token}" -H "Content-Type: application/json" -XPOST -d '{ "name":"cloud", "organization" : "default", "applicationName" : "cloud"  }' http://localhost:8080/management/orgs/default/apps
    fi
}

function config_local {
cat <<EOF >> ${USER_GRID_PROPERTIES_FILE}
usergrid.management.mailer=UserGrid<usergrid-mailer@test.com>
usergrid.test-account.admin-user.email=user@test.com
usergrid.test-account.admin-user.password=pass79
EOF
}

function validate_cassandra_host {
    if [ -z ${cassandraHosts+x} ]; then
        cassandraHosts="127.0.0.1:9160"
        echo "cassandraHosts not provided, using default --> ${cassandraHosts}"
    fi
}
function config_cassandra_host {
validate_cassandra_host
cat <<EOF >> ${USER_GRID_PROPERTIES_FILE}
cassandra.url=${cassandraHosts}
cassandra.username=${cassandraUsername}
cassandra.password=${cassandraPassword}
EOF
}

function validate_mail {
    ## do these first so that we can use mailAuth to check for user/pass
    if [ -z ${mailAuth+x} ]; then
        mailAuth=true
        echo "mailAuth not provided, using default --> ${mailAuth}"
    fi
    if [ -z ${mailTransportProtocol+x} ]; then
        mailTransportProtocol="smtps"
        echo "mailTransportProtocol not provided, using default --> ${mailTransportProtocol}"
    fi
    if [ -z ${mailQuitWait+x} ]; then
        mailQuitWait=false
        echo "mailQuitWait not provided, using default --> ${mailQuitWait}"
    fi


    requirementsMeet=true
    if [ -z ${mailServerHost+x} ]; then
        requirementsMeet=false
        echo "mailServerHost not provided, it is a required field."
    fi
    if [ -z ${mailServerPort+x} ]; then
        requirementsMeet=false
        echo "mailServerPort not provided, it is a required field."
    fi
    if [ "${mailServerHost}" == "true" ]; then
        if [ -z ${mailAuthUsername+x} ]; then
            requirementsMeet=false
            echo "mailAuthUsername not provided, it is a required field."
        fi
        if [ -z ${mailAuthPassword+x} ]; then
            requirementsMeet=false
            echo "mailAuthPassword not provided, it is a required field."
        fi
    fi


    if [ "${requirementsMeet}" == "false" ]; then
        echo "requirements not meet for request, aborting."
        exit 1
    fi


}
function config_mail {
validate_mail
cat <<EOF >> ${USER_GRID_PROPERTIES_FILE}
mail.transport.protocol=${mailTransportProtocol}
mail.smtps.host=${mailServerHost}
mail.smtps.port=${mailServerPort}
mail.smtps.auth=${mailAuth}
mail.smtps.quitwait=${mailQuitWait}
mail.smtps.username=${mailAuthUsername}
mail.smtps.password=${mailAuthPassword}
EOF

}

function validate_users {
    # some of these are required, so we do those first.
    requirementsMeet=true
    if [ -z ${sysadminLoginEmail+x} ]; then
        requirementsMeet=false
        echo "sysadminLoginEmail not provided, it is a required field."
    fi
    if [ -z ${sysadminLoginPassword+x} ]; then
        requirementsMeet=false
        echo "sysadminLoginPassword not provided, it is a required field."
    fi
    if [ -z ${sysadminEmail+x} ]; then
        requirementsMeet=false
        echo "sysadminEmail not provided, it is a required field."
    fi

    if [ "${requirementsMeet}" == "false" ]; then
        echo "requirements not meet for request, aborting."
        exit 1
    fi

    if [ -z ${sysadminLoginName+x} ]; then
        sysadminLoginName="superuser"
        echo "sysadminLoginName not provided, using default --> ${sysadminLoginName}"
    fi
    if [ -z ${sysadminLoginAllowed+x} ]; then
        sysadminLoginAllowed=true
        echo "sysadminLoginAllowed not provided, using default --> ${sysadminLoginAllowed}"
    fi
    if [ -z ${sysadminApproveUsers+x} ]; then
        sysadminApproveUsers=false
        echo "sysadminApproveUsers not provided, using default --> ${sysadminApproveUsers}"
    fi
}
function config_users {
validate_users
cat <<EOF >> ${USER_GRID_PROPERTIES_FILE}
usergrid.sysadmin.login.name=${sysadminLoginName}
usergrid.sysadmin.login.email=${sysadminLoginEmail}
usergrid.sysadmin.login.password=${sysadminLoginPassword}
usergrid.sysadmin.login.allowed=${sysadminLoginAllowed}
usergrid.sysadmin.email=${sysadminEmail}
usergrid.sysadmin.approve.users=${sysadminApproveUsers}
EOF

}

function validate_notifications {
    if [ -z ${adminUsersRequireConfirmation+x} ]; then
        adminUsersRequireConfirmation=false
        echo "adminUsersRequireConfirmation not provided, using default --> ${adminUsersRequireConfirmation}"
    fi
    if [ -z ${adminUsersRequireActivation+x} ]; then
        adminUsersRequireActivation=false
        echo "adminUsersRequireActivation not provided, using default --> ${adminUsersRequireActivation}"
    fi
    if [ -z ${notifyAdminOfActivation+x} ]; then
        notifyAdminOfActivation=false
        echo "notifyAdminOfActivation not provided, using default --> ${notifyAdminOfActivation}"
    fi
    if [ -z ${orgsRequireConfirmation+x} ]; then
        orgsRequireConfirmation=false
        echo "orgsRequireConfirmation not provided, using default --> ${orgsRequireConfirmation}"
    fi
    if [ -z ${orgsRequireActivation+x} ]; then
        orgsRequireActivation=false
        echo "orgsRequireActivation not provided, using default --> ${orgsRequireActivation}"
    fi
    if [ -z ${notifySysAdminOnNewOrgs+x} ]; then
        notifySysAdminOnNewOrgs=false
        echo "notifySysAdminOnNewOrgs not provided, using default --> ${notifySysAdminOnNewOrgs}"
    fi
    if [ -z ${notifySysAdminOnNewAdmins+x} ]; then
        notifySysAdminOnNewAdmins=false
        echo "notifySysAdminOnNewAdmins not provided, using default --> ${notifySysAdminOnNewAdmins}"
    fi
}
function config_notifications {
validate_notifications
cat <<EOF >> ${USER_GRID_PROPERTIES_FILE}
usergrid.management.admin_users_require_confirmation=${adminUsersRequireConfirmation}
usergrid.management.admin_users_require_activation=${adminUsersRequireActivation}
usergrid.management.notify_admin_of_activation=${notifyAdminOfActivation}
usergrid.management.organizations_require_confirmation=${orgsRequireConfirmation}
usergrid.management.organizations_require_activation=${orgsRequireActivation}
usergrid.management.notify_sysadmin_of_new_organizations=${notifySysAdminOnNewOrgs}
usergrid.management.notify_sysadmin_of_new_admin_users=${notifySysAdminOnNewAdmins}
EOF

}

function validate_asset_handling {
    # some of these are required, so we do those first.
    requirementsMeet=true
    if [ -z ${awsAccessKey+x} ]; then
        requirementsMeet=false
        echo "awsAccessKey not provided, this field is required."
    fi
    if [ -z ${awsSecretKey+x} ]; then
        requirementsMeet=false
        echo "awsSecretKey not provided, this field is required."
    fi
    if [ -z ${s3AssetsBucket+x} ]; then
        requirementsMeet=false
        echo "s3AssetsBucket not provided, this field is required."
    fi

    if [ "${requirementsMeet}" == "false" ]; then
        echo "S3 Asset Handling requirements not meet for request, aborting."
        exit 1
    fi
}
function config_asset_handling {
validate_asset_handling
cat <<EOF >> ${USER_GRID_PROPERTIES_FILE}
AWS_ACCESS_KEY_ID=${awsAccessKey}
AWS_SECRET_KEY=${awsSecretKey}
usergrid.binary.bucketname=${s3AssetsBucket}
EOF
}

function validate_mappings {
    # some of these are required, so we do those first.
    requirementsMeet=true
    if [ -z ${userGridLoadBalancerUrl+x} ]; then
        requirementsMeet=false
        echo "userGridLoadBalancerUrl not provided, this field is required."
    fi
    if [ -z ${managementMailerEmail+x} ]; then
        requirementsMeet=false
        echo "managementMailerEmail not provided, this field is required."
    fi

    if [ "${requirementsMeet}" == "false" ]; then
        echo "URL Mapping requirements not meet for request, aborting."
        exit 1
    fi
}
function config_url_mappings {
validate_mappings
cat <<EOF >> ${USER_GRID_PROPERTIES_FILE}
usergrid.redirect_root=${userGridLoadBalancerUrl}
usergrid.view.management.organizations.organization.activate=${userGridLoadBalancerUrl}/accounts/welcome
usergrid.view.management.organizations.organization.confirm=${userGridLoadBalancerUrl}/accounts/welcome
usergrid.view.management.users.user.activate=${userGridLoadBalancerUrl}/accounts/welcome
usergrid.view.management.users.user.confirm=${userGridLoadBalancerUrl}/accounts/welcome
usergrid.organization.activation.url=${userGridLoadBalancerUrl}/management/organizations/%s/activate
usergrid.admin.activation.url=${userGridLoadBalancerUrl}/management/users/%s/activate
usergrid.admin.resetpw.url=${userGridLoadBalancerUrl}/management/users/%s/resetpw
usergrid.admin.confirmation.url=${userGridLoadBalancerUrl}/management/users/%s/confirm
usergrid.user.activation.url=${userGridLoadBalancerUrl}/%s/%s/users/%s/activate
usergrid.user.confirmation.url=${userGridLoadBalancerUrl}/%s/%s/users/%s/confirm
usergrid.user.resetpw.url=${userGridLoadBalancerUrl}/%s/%s/users/%s/resetpw
usergrid.management.mailer=${managementMailerEmail}
EOF

}

function validate_cassandra {
    if [ -z ${cassKeyspaceStrategy+x} ]; then
        cassKeyspaceStrategy="org.apache.cassandra.locator.SimpleStrategy"
        echo "cassandraHosts not provided, using default --> ${cassandraHosts}"
    fi
    if [ -z ${cassStrategyReplicationFactor+x} ]; then
        cassStrategyReplicationFactor=1
        echo "cassStrategyReplicationFactor not provided, using default --> ${cassStrategyReplicationFactor}"
    fi
    if [ -z ${cassNumberOfConnectionsPerHost+x} ]; then
        cassNumberOfConnectionsPerHost=50
        echo "cassNumberOfConnectionsPerHost not provided, using default --> ${cassNumberOfConnectionsPerHost}"
    fi
    if [ -z ${cassClusterName+x} ]; then
        cassClusterName="UGCassCluster"
        echo "cassClusterName not provided, using default --> ${cassClusterName}"
    fi
    if [ -z ${cassWriteConsistencyLevel+x} ]; then
        cassWriteConsistencyLevel="QUORUM"
        echo "cassWriteConsistencyLevel not provided, using default --> ${cassWriteConsistencyLevel}"
    fi
    if [ -z ${cassReadConsistencyLevel+x} ]; then
        cassReadConsistencyLevel="QUORUM"
        echo "cassReadConsistencyLevel not provided, using default --> ${cassReadConsistencyLevel}"
    fi
    if [ -z ${cassKeyspaceStrategyOptions+x} ]; then
        cassKeyspaceStrategyOptions=""
        echo "cassKeyspaceStrategyOptions not provided, using default --> ${cassKeyspaceStrategyOptions}"
    fi
}

function config_cassandra {
validate_cassandra
cat <<EOF >> ${USER_GRID_PROPERTIES_FILE}
cassandra.keyspace.strategy=${cassKeyspaceStrategy}
cassandra.keyspace.strategy.options.replication_factor=${cassStrategyReplicationFactor}
cassandra.connections=${cassNumberOfConnectionsPerHost}
cassandra.cluster=${cassClusterName}
cassandra.writecl=${cassWriteConsistencyLevel}
cassandra.readcl=${cassReadConsistencyLevel}
EOF
## removed this item from the list ${cassKeyspaceStrategyOptions}
}

function validate_counters {
    if [ -z ${counterBatchSize+x} ]; then
        counterBatchSize=10000
        echo "counterBatchSize not provided, using default --> ${counterBatchSize}"
    fi
    if [ -z ${counterBatchInterval+x} ]; then
        counterBatchInterval=30
        echo "counterBatchInterval not provided, using default --> ${counterBatchInterval}"
    fi
    if [ -z ${counterSkipAggregate+x} ]; then
        counterSkipAggregate=false
        echo "counterSkipAggregate not provided, using default --> ${counterSkipAggregate}"
    fi
}
function config_counters {
validate_counters
cat <<EOF >> ${USER_GRID_PROPERTIES_FILE}
usergrid.counter.batch.size=${counterBatchSize}
usergrid.counter.batch.interval=${counterBatchInterval}
usergrid.counter.skipAggregate=false${counterSkipAggregate}
EOF

}
function disable_counters {
validate_counters
cat <<EOF >> ${USER_GRID_PROPERTIES_FILE}
usergrid.counter.skipAggregate=true
EOF

}

function validate_schedulers {
    if [ -z ${schedulerEnabled+x} ]; then
        schedulerEnabled=true
        echo "schedulerEnabled not provided, using default --> ${schedulerEnabled}"
    fi
    if [ -z ${schedulerTimeout+x} ]; then
        schedulerTimeout=30000
        echo "schedulerTimeout not provided, using default --> ${schedulerTimeout}"
    fi
    if [ -z ${schedulerQueueName+x} ]; then
        schedulerQueueName=/jobs
        echo "schedulerQueueName not provided, using default --> ${schedulerQueueName}"
    fi
    if [ -z ${schedulerNumberWorkers+x} ]; then
        schedulerNumberWorkers=1
        echo "schedulerNumberWorkers not provided, using default --> ${schedulerNumberWorkers}"
    fi
    if [ -z ${schedulerIntervalMills+x} ]; then
        schedulerIntervalMills=1000
        echo "schedulerIntervalMills not provided, using default --> ${schedulerIntervalMills}"
    fi
    if [ -z ${schedulerMaxFail+x} ]; then
        schedulerMaxFail=10
        echo "schedulerMaxFail not provided, using default --> ${schedulerMaxFail}"
    fi
}
function config_schedulers {
validate_schedulers
cat <<EOF >> ${USER_GRID_PROPERTIES_FILE}
usergrid.scheduler.enabled=${schedulerEnabled}
usergrid.scheduler.job.timeout=${schedulerTimeout}
usergrid.scheduler.job.queueName=${schedulerQueueName}
usergrid.scheduler.job.workers=${schedulerNumberWorkers}
usergrid.scheduler.job.interval=${schedulerIntervalMills}
usergrid.scheduler.job.maxfail=${schedulerMaxFail}
EOF
}
function disable_schedulers {
validate_schedulers
cat <<EOF >> ${USER_GRID_PROPERTIES_FILE}
usergrid.scheduler.enabled=false
EOF
}

function validate {
    if [ -z ${initUserGrid+x} ]; then
        echo "initUserGrid was not provided, this field specifies if we run curl commands to setup user grid. Defaults to false."
        initUserGrid=false
    fi
    if [ -z ${installType+x} ]; then
        echo "installType was not provided, this field specifies how we install user grid - options : local and advanced.  If not provided defaults to EC2."
        installType=
    fi
}
function main {
  options "$@"
  validate
  install_usergrid
}

if [[ ${1:-} ]] && declare -F | cut -d' ' -f3 | fgrep -qx -- "${1:-}"
then "$@"
else main "$@"
fi
