#!/bin/bash
if [ $# -eq 6 ]
 then
    echo "Getting required parameters "
 else    
    echo "please add required parameters"
    exit 1
 fi
function yum_repo_setting()
{
rpm --import https://packages.elastic.co/GPG-KEY-elasticsearch
cat > /etc/yum.repos.d/elastic.repo << EOF
[elasticsearch-6.x]
name=Elasticsearch repository for 6.x packages
baseurl=https://artifacts.elastic.co/packages/6.x/yum
gpgcheck=1
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
enabled=1
autorefresh=1
type=rpm-md
EOF
}

function install_elk()
{
  echo "Installing java"
  yum install -q -y java-1.8.0-openjdk || { echo "java install failed."; exit 1;}
  echo "Installing Elasticsearch"
  yum install -q -y elasticsearch-6.8.9 || { echo "elasticsearch install failed."; exit 1;}
  # yum install -q -y logstash-6.5.4 || { echo "logstash install failed."; exit 1;}
  # yum install -q -y kibana-6.5.4 || { echo "kibana install failed."; exit 1;}
  # curl -L -O https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-6.5.4-x86_64.rpm
  # yum install -q -y filebeat-6.5.4-x86_64.rpm || { echo "metricbeat install failed."; exit 1;}
  # curl -L -O https://artifacts.elastic.co/downloads/beats/metricbeat/metricbeat-6.5.4-x86_64.rpm
  # yum install -q -y metricbeat-6.5.4-x86_64.rpm || { echo "metricbeat install failed."; exit 1;}
}

function elk_config_setting()
{
  echo "cluster.name = $1 "
  echo "node.name = $2 "
  echo "node.attr.fault_domain = $3 "
  echo "node.attr.update_domain = $4 "
  echo "discovery.zen.ping.unicast.hosts= $5 "
  echo "discovery.zen.minimum_master_nodes= $6 "
  mkdir /data
  chown elasticsearch. /data
  rm -rf /var/log/elasticsearch/*
  rm -rf /var/lib/elasticsearch/*
  echo " Taking elasticsearch.yml backup"
  sudo cp /etc/elasticsearch/elasticsearch.yml /etc/elasticsearch/elasticsearch.yml.bak
  echo " clearing existing configuration"
  echo > /etc/elasticsearch/elasticsearch.yml
  echo " adding new configuration"
  cat >>/etc/elasticsearch/elasticsearch.yml<<EOF
cluster.name: "$1"
node.name: "$2"
path.logs: /datadisks/disk1/elasticsearch/logs
path.data: /datadisks/disk1/elasticsearch/data
discovery.zen.ping.unicast.hosts: $5
discovery.zen.minimum_master_nodes: $6
node.master: true
node.data: true
network.host: [_site_, _local_]
node.max_local_storage_nodes: 1
node.attr.fault_domain: $3
node.attr.update_domain: $4
cluster.routing.allocation.awareness.attributes: fault_domain,update_domain
bootstrap.memory_lock: true
EOF
  # sed -i 's/^#network.host:.*/network.host: [_site_, _local_]/g' /etc/elasticsearch/elasticsearch.yml
  # sed -i 's/^#cluster.name:.*/cluster.name: Fcs-cluster/' /etc/elasticsearch/elasticsearch.yml
  # sed -i 's/^#node.name:.*/node.name: '\$\{HOSTNAME\}'/g' /etc/elasticsearch/elasticsearch.yml
  # echo -e 'node.master: true\nnode.data: true' >> /etc/elasticsearch/elasticsearch.yml
  # #sed -i 's/^#server.host:.*/server.host: "0.0.0.0"/g' /etc/kibana/kibana.yml
  # #sed -i 's/^#logging.dest:.*/logging.dest: \/etc\/kibana\/kibana.log/' /etc/kibana/kibana.yml
  # #chown kibana. /etc/
  
  mkdir -p /etc/systemd/system/elasticsearch.service.d
  echo -e '[Service]\nLimitMEMLOCK=infinity' > /etc/systemd/system/elasticsearch.service.d/override.conf
  #sed -i 's/^path.data: \/var\/lib\/elasticsearch/path.data: \/data/g' /etc/elasticsearch/elasticsearch.yml
  echo " configuring jvm.options"
  echo " Taking jvm.options backup"
  sudo cp /etc/elasticsearch/jvm.options /etc/elasticsearch/jvm.options.bak
  echo " clearing existing jvm.options configuration"
  echo > /etc/elasticsearch/jvm.options
  echo " adding new jvm.options configuration"
  cat >>/etc/elasticsearch/jvm.options<<EOF
## JVM configuration

################################################################
## IMPORTANT: JVM heap size
################################################################
##
## You should always set the min and max JVM heap
## size to the same value. For example, to set
## the heap to 4 GB, set:
##
## -Xms4g
## -Xmx4g
##
## See https://www.elastic.co/guide/en/elasticsearch/reference/current/heap-size.html
## for more information
##
################################################################

# Xms represents the initial size of total heap space
# Xmx represents the maximum size of total heap space

-Xms1g
-Xmx1g

################################################################
## Expert settings
################################################################
##
## All settings below this section are considered
## expert settings. Don't tamper with them unless
## you understand what you are doing
##
################################################################

## GC configuration
8-13:-XX:+UseConcMarkSweepGC
8-13:-XX:CMSInitiatingOccupancyFraction=75
8-13:-XX:+UseCMSInitiatingOccupancyOnly

## G1GC Configuration
# NOTE: G1 GC is only supported on JDK version 10 or later
# to use G1GC, uncomment the next two lines and update the version on the
# following three lines to your version of the JDK
# 10-13:-XX:-UseConcMarkSweepGC
# 10-13:-XX:-UseCMSInitiatingOccupancyOnly
14-:-XX:+UseG1GC
14-:-XX:G1ReservePercent=25
14-:-XX:InitiatingHeapOccupancyPercent=30

## DNS cache policy
# cache ttl in seconds for positive DNS lookups noting that this overrides the
# JDK security property networkaddress.cache.ttl; set to -1 to cache forever
-Des.networkaddress.cache.ttl=60
# cache ttl in seconds for negative DNS lookups noting that this overrides the
# JDK security property networkaddress.cache.negative ttl; set to -1 to cache
# forever
-Des.networkaddress.cache.negative.ttl=10

## optimizations

# pre-touch memory pages used by the JVM during initialization
-XX:+AlwaysPreTouch

## basic

# explicitly set the stack size
-Xss1m

# set to headless, just in case
-Djava.awt.headless=true

# ensure UTF-8 encoding by default (e.g. filenames)
-Dfile.encoding=UTF-8

# use our provided JNA always versus the system one
-Djna.nosys=true

# turn off a JDK optimization that throws away stack traces for common
# exceptions because stack traces are important for debugging
-XX:-OmitStackTraceInFastThrow

# enable helpful NullPointerExceptions (https://openjdk.java.net/jeps/358), if
# they are supported
14-:-XX:+ShowCodeDetailsInExceptionMessages

# flags to configure Netty
-Dio.netty.noUnsafe=true
-Dio.netty.noKeySetOptimization=true
-Dio.netty.recycler.maxCapacityPerThread=0

# log4j 2
-Dlog4j.shutdownHookEnabled=false
-Dlog4j2.disable.jmx=true

-Djava.io.tmpdir=${ES_TMPDIR}

## heap dumps

# generate a heap dump when an allocation from the Java heap fails
# heap dumps are created in the working directory of the JVM
-XX:+HeapDumpOnOutOfMemoryError

# specify an alternative path for heap dumps; ensure the directory exists and
# has sufficient space
-XX:HeapDumpPath=/var/lib/elasticsearch

# specify an alternative path for JVM fatal error logs
-XX:ErrorFile=/var/log/elasticsearch/hs_err_pid%p.log

## JDK 8 GC logging

8:-XX:+PrintGCDetails
8:-XX:+PrintGCDateStamps
8:-XX:+PrintTenuringDistribution
8:-XX:+PrintGCApplicationStoppedTime
8:-Xloggc:/var/log/elasticsearch/gc.log
8:-XX:+UseGCLogFileRotation
8:-XX:NumberOfGCLogFiles=32
8:-XX:GCLogFileSize=64m

# JDK 9+ GC logging
9-:-Xlog:gc*,gc+age=trace,safepoint:file=/var/log/elasticsearch/gc.log:utctime,pid,tags:filecount=32,filesize=64m
# due to internationalization enhancements in JDK 9 Elasticsearch need to set the provider to COMPAT otherwise
# time/date parsing will break in an incompatible way for some date patterns and locals
9-:-Djava.locale.providers=COMPAT

# temporary workaround for C2 bug with JDK 10 on hardware with AVX-512
10-:-XX:UseAVX=2
EOF
  JVM_MEM=`cat /proc/meminfo | sed -n '1p' | awk '{printf("%.0f\n",$2/1024/1024/2)}'`
  echo " Jvm memory to be set is $JVM_MEM"
  sed -i "s/^-Xms.*g/-Xms${JVM_MEM}g/g" /etc/elasticsearch/jvm.options
  sed -i "s/^-Xmx.*g/-Xmx${JVM_MEM}g/g" /etc/elasticsearch/jvm.options
  echo " Taking log4j2.properties backup"
  sudo cp /etc/elasticsearch/log4j2.properties /etc/elasticsearch/log4j2.properties.bak
  echo " clearing existing log4j2.properties configuration"
  echo > /etc/elasticsearch/log4j2.properties
  echo " adding new configuration to log4j2.properties"
  cat >>/etc/elasticsearch/log4j2.properties<<EOF
status = error

# log action execution errors for easier debugging
logger.action.name = org.elasticsearch.action
logger.action.level = debug

appender.console.type = Console
appender.console.name = console
appender.console.layout.type = PatternLayout
appender.console.layout.pattern = [%d{ISO8601}][%-5p][%-25c{1.}] [%node_name]%marker %m%n

appender.rolling.type = RollingFile
appender.rolling.name = rolling
appender.rolling.fileName = ${sys:es.logs.base_path}${sys:file.separator}${sys:es.logs.cluster_name}.log
appender.rolling.layout.type = PatternLayout
appender.rolling.layout.pattern = [%d{ISO8601}][%-5p][%-25c{1.}] [%node_name]%marker %.-10000m%n
appender.rolling.filePattern = ${sys:es.logs.base_path}${sys:file.separator}${sys:es.logs.cluster_name}-%d{yyyy-MM-dd}-%i.log.gz
appender.rolling.policies.type = Policies
appender.rolling.policies.time.type = TimeBasedTriggeringPolicy
appender.rolling.policies.time.interval = 1
appender.rolling.policies.time.modulate = true
appender.rolling.policies.size.type = SizeBasedTriggeringPolicy
appender.rolling.policies.size.size = 128MB
appender.rolling.strategy.type = DefaultRolloverStrategy
appender.rolling.strategy.fileIndex = nomax
appender.rolling.strategy.action.type = Delete
appender.rolling.strategy.action.basepath = ${sys:es.logs.base_path}
appender.rolling.strategy.action.condition.type = IfFileName
appender.rolling.strategy.action.condition.glob = ${sys:es.logs.cluster_name}-*
appender.rolling.strategy.action.condition.nested_condition.type = IfAccumulatedFileSize
appender.rolling.strategy.action.condition.nested_condition.exceeds = 2GB

rootLogger.level = info
rootLogger.appenderRef.console.ref = console
rootLogger.appenderRef.rolling.ref = rolling

appender.deprecation_rolling.type = RollingFile
appender.deprecation_rolling.name = deprecation_rolling
appender.deprecation_rolling.fileName = ${sys:es.logs.base_path}${sys:file.separator}${sys:es.logs.cluster_name}_deprecation.log
appender.deprecation_rolling.layout.type = PatternLayout
appender.deprecation_rolling.layout.pattern = [%d{ISO8601}][%-5p][%-25c{1.}] [%node_name]%marker %.-10000m%n
appender.deprecation_rolling.filePattern = ${sys:es.logs.base_path}${sys:file.separator}${sys:es.logs.cluster_name}_deprecation-%i.log.gz
appender.deprecation_rolling.policies.type = Policies
appender.deprecation_rolling.policies.size.type = SizeBasedTriggeringPolicy
appender.deprecation_rolling.policies.size.size = 1GB
appender.deprecation_rolling.strategy.type = DefaultRolloverStrategy
appender.deprecation_rolling.strategy.max = 4

logger.deprecation.name = org.elasticsearch.deprecation
logger.deprecation.level = warn
logger.deprecation.appenderRef.deprecation_rolling.ref = deprecation_rolling
logger.deprecation.additivity = false

appender.index_search_slowlog_rolling.type = RollingFile
appender.index_search_slowlog_rolling.name = index_search_slowlog_rolling
appender.index_search_slowlog_rolling.fileName = ${sys:es.logs.base_path}${sys:file.separator}${sys:es.logs.cluster_name}_index_search_slowlog.log
appender.index_search_slowlog_rolling.layout.type = PatternLayout
appender.index_search_slowlog_rolling.layout.pattern = [%d{ISO8601}][%-5p][%-25c] [%node_name]%marker %.-10000m%n
appender.index_search_slowlog_rolling.filePattern = ${sys:es.logs.base_path}${sys:file.separator}${sys:es.logs.cluster_name}_index_search_slowlog-%d{yyyy-MM-dd}.log
appender.index_search_slowlog_rolling.policies.type = Policies
appender.index_search_slowlog_rolling.policies.time.type = TimeBasedTriggeringPolicy
appender.index_search_slowlog_rolling.policies.time.interval = 1
appender.index_search_slowlog_rolling.policies.time.modulate = true

logger.index_search_slowlog_rolling.name = index.search.slowlog
logger.index_search_slowlog_rolling.level = trace
logger.index_search_slowlog_rolling.appenderRef.index_search_slowlog_rolling.ref = index_search_slowlog_rolling
logger.index_search_slowlog_rolling.additivity = false

appender.index_indexing_slowlog_rolling.type = RollingFile
appender.index_indexing_slowlog_rolling.name = index_indexing_slowlog_rolling
appender.index_indexing_slowlog_rolling.fileName = ${sys:es.logs.base_path}${sys:file.separator}${sys:es.logs.cluster_name}_index_indexing_slowlog.log
appender.index_indexing_slowlog_rolling.layout.type = PatternLayout
appender.index_indexing_slowlog_rolling.layout.pattern = [%d{ISO8601}][%-5p][%-25c] [%node_name]%marker %.-10000m%n
appender.index_indexing_slowlog_rolling.filePattern = ${sys:es.logs.base_path}${sys:file.separator}${sys:es.logs.cluster_name}_index_indexing_slowlog-%d{yyyy-MM-dd}.log
appender.index_indexing_slowlog_rolling.policies.type = Policies
appender.index_indexing_slowlog_rolling.policies.time.type = TimeBasedTriggeringPolicy
appender.index_indexing_slowlog_rolling.policies.time.interval = 1
appender.index_indexing_slowlog_rolling.policies.time.modulate = true

logger.index_indexing_slowlog.name = index.indexing.slowlog.index
logger.index_indexing_slowlog.level = trace
logger.index_indexing_slowlog.appenderRef.index_indexing_slowlog_rolling.ref = index_indexing_slowlog_rolling
logger.index_indexing_slowlog.additivity = false


appender.audit_rolling.type = RollingFile
appender.audit_rolling.name = audit_rolling
appender.audit_rolling.fileName = ${sys:es.logs.base_path}${sys:file.separator}${sys:es.logs.cluster_name}_audit.log
appender.audit_rolling.layout.type = PatternLayout
appender.audit_rolling.layout.pattern = {\
                "@timestamp":"%d{ISO8601}"\
                %varsNotEmpty{, "node.name":"%enc{%map{node.name}}{JSON}"}\
                %varsNotEmpty{, "node.id":"%enc{%map{node.id}}{JSON}"}\
                %varsNotEmpty{, "host.name":"%enc{%map{host.name}}{JSON}"}\
                %varsNotEmpty{, "host.ip":"%enc{%map{host.ip}}{JSON}"}\
                %varsNotEmpty{, "event.type":"%enc{%map{event.type}}{JSON}"}\
                %varsNotEmpty{, "event.action":"%enc{%map{event.action}}{JSON}"}\
                %varsNotEmpty{, "user.name":"%enc{%map{user.name}}{JSON}"}\
                %varsNotEmpty{, "user.run_by.name":"%enc{%map{user.run_by.name}}{JSON}"}\
                %varsNotEmpty{, "user.run_as.name":"%enc{%map{user.run_as.name}}{JSON}"}\
                %varsNotEmpty{, "user.realm":"%enc{%map{user.realm}}{JSON}"}\
                %varsNotEmpty{, "user.run_by.realm":"%enc{%map{user.run_by.realm}}{JSON}"}\
                %varsNotEmpty{, "user.run_as.realm":"%enc{%map{user.run_as.realm}}{JSON}"}\
                %varsNotEmpty{, "user.roles":%map{user.roles}}\
                %varsNotEmpty{, "origin.type":"%enc{%map{origin.type}}{JSON}"}\
                %varsNotEmpty{, "origin.address":"%enc{%map{origin.address}}{JSON}"}\
                %varsNotEmpty{, "realm":"%enc{%map{realm}}{JSON}"}\
                %varsNotEmpty{, "url.path":"%enc{%map{url.path}}{JSON}"}\
                %varsNotEmpty{, "url.query":"%enc{%map{url.query}}{JSON}"}\
                %varsNotEmpty{, "request.method":"%enc{%map{request.method}}{JSON}"}\
                %varsNotEmpty{, "request.body":"%enc{%map{request.body}}{JSON}"}\
                %varsNotEmpty{, "request.id":"%enc{%map{request.id}}{JSON}"}\
                %varsNotEmpty{, "action":"%enc{%map{action}}{JSON}"}\
                %varsNotEmpty{, "request.name":"%enc{%map{request.name}}{JSON}"}\
                %varsNotEmpty{, "indices":%map{indices}}\
                %varsNotEmpty{, "opaque_id":"%enc{%map{opaque_id}}{JSON}"}\
                %varsNotEmpty{, "x_forwarded_for":"%enc{%map{x_forwarded_for}}{JSON}"}\
                %varsNotEmpty{, "transport.profile":"%enc{%map{transport.profile}}{JSON}"}\
                %varsNotEmpty{, "rule":"%enc{%map{rule}}{JSON}"}\
                %varsNotEmpty{, "event.category":"%enc{%map{event.category}}{JSON}"}\
                }%n
# "node.name" node name from the `elasticsearch.yml` settings
# "node.id" node id which should not change between cluster restarts
# "host.name" unresolved hostname of the local node
# "host.ip" the local bound ip (i.e. the ip listening for connections)
# "event.type" a received REST request is translated into one or more transport requests. This indicates which processing layer generated the event "rest" or "transport" (internal)
# "event.action" the name of the audited event, eg. "authentication_failed", "access_granted", "run_as_granted", etc.
# "user.name" the subject name as authenticated by a realm
# "user.run_by.name" the original authenticated subject name that is impersonating another one.
# "user.run_as.name" if this "event.action" is of a run_as type, this is the subject name to be impersonated as.
# "user.realm" the name of the realm that authenticated "user.name"
# "user.run_by.realm" the realm name of the impersonating subject ("user.run_by.name")
# "user.run_as.realm" if this "event.action" is of a run_as type, this is the realm name the impersonated user is looked up from
# "user.roles" the roles array of the user; these are the roles that are granting privileges
# "origin.type" it is "rest" if the event is originating (is in relation to) a REST request; possible other values are "transport" and "ip_filter"
# "origin.address" the remote address and port of the first network hop, i.e. a REST proxy or another cluster node
# "realm" name of a realm that has generated an "authentication_failed" or an "authentication_successful"; the subject is not yet authenticated
# "url.path" the URI component between the port and the query string; it is percent (URL) encoded
# "url.query" the URI component after the path and before the fragment; it is percent (URL) encoded
# "request.method" the method of the HTTP request, i.e. one of GET, POST, PUT, DELETE, OPTIONS, HEAD, PATCH, TRACE, CONNECT
# "request.body" the content of the request body entity, JSON escaped
# "request.id" a synthentic identifier for the incoming request, this is unique per incoming request, and consistent across all audit events generated by that request
# "action" an action is the most granular operation that is authorized and this identifies it in a namespaced way (internal)
# "request.name" if the event is in connection to a transport message this is the name of the request class, similar to how rest requests are identified by the url path (internal)
# "indices" the array of indices that the "action" is acting upon
# "opaque_id" opaque value conveyed by the "X-Opaque-Id" request header
# "x_forwarded_for" the addresses from the "X-Forwarded-For" request header, as a verbatim string value (not an array)
# "transport.profile" name of the transport profile in case this is a "connection_granted" or "connection_denied" event
# "rule" name of the applied rulee if the "origin.type" is "ip_filter"
# "event.category" fixed value "elasticsearch-audit"

appender.audit_rolling.filePattern = ${sys:es.logs.base_path}${sys:file.separator}${sys:es.logs.cluster_name}_audit-%d{yyyy-MM-dd}.log
appender.audit_rolling.policies.type = Policies
appender.audit_rolling.policies.time.type = TimeBasedTriggeringPolicy
appender.audit_rolling.policies.time.interval = 1
appender.audit_rolling.policies.time.modulate = true

appender.deprecated_audit_rolling.type = RollingFile
appender.deprecated_audit_rolling.name = deprecated_audit_rolling
appender.deprecated_audit_rolling.fileName = ${sys:es.logs.base_path}${sys:file.separator}${sys:es.logs.cluster_name}_access.log
appender.deprecated_audit_rolling.layout.type = PatternLayout
appender.deprecated_audit_rolling.layout.pattern = [%d{ISO8601}] %m%n
appender.deprecated_audit_rolling.filePattern = ${sys:es.logs.base_path}${sys:file.separator}${sys:es.logs.cluster_name}_access-%d{yyyy-MM-dd}.log
appender.deprecated_audit_rolling.policies.type = Policies
appender.deprecated_audit_rolling.policies.time.type = TimeBasedTriggeringPolicy
appender.deprecated_audit_rolling.policies.time.interval = 1
appender.deprecated_audit_rolling.policies.time.modulate = true

logger.xpack_security_audit_logfile.name = org.elasticsearch.xpack.security.audit.logfile.LoggingAuditTrail
logger.xpack_security_audit_logfile.level = info
logger.xpack_security_audit_logfile.appenderRef.audit_rolling.ref = audit_rolling
logger.xpack_security_audit_logfile.additivity = false

logger.xpack_security_audit_deprecated_logfile.name = org.elasticsearch.xpack.security.audit.logfile.DeprecatedLoggingAuditTrail
# set this to "off" instead of "info" to disable the deprecated appender
# in the 6.x releases both the new and the previous appenders are enabled
# for the logfile auditing
logger.xpack_security_audit_deprecated_logfile.level = info
logger.xpack_security_audit_deprecated_logfile.appenderRef.deprecated_audit_rolling.ref = deprecated_audit_rolling
logger.xpack_security_audit_deprecated_logfile.additivity = false

logger.xmlsig.name = org.apache.xml.security.signature.XMLSignature
logger.xmlsig.level = error
logger.samlxml_decrypt.name = org.opensaml.xmlsec.encryption.support.Decrypter
logger.samlxml_decrypt.level = fatal
logger.saml2_decrypt.name = org.opensaml.saml.saml2.encryption.Decrypter
logger.saml2_decrypt.level = fatal
EOF
}

function start_elk_service()
{
  systemctl daemon-reload
  # systemctl start logstash
  systemctl start elasticsearch
  # systemctl start kibana
  # systemctl start filebeat
  # systemctl start metricbeat
  swapoff -a
}

function enable_elk_service()
{
  # systemctl enable logstash
  systemctl enable elasticsearch
  # systemctl enable kibana
  # systemctl enable filebeat
  # systemctl enable metricbeat
}

function status_elk_service()
{
  java -version
  # systemctl status logstash
  systemctl status elasticsearch
  # systemctl status kibana
  # systemctl status filebeat
  # systemctl status metricbeat
}


#------------------------------------------------------------------
echo " Adding Elastic Repository"
yum_repo_setting
install_elk
elk_config_setting "$1" "$2" "$3" "$4" "$5" "$6"
start_elk_service
enable_elk_service
status_elk_service

echo "ELK stack installation finished. Please check there is any error output."

exit 0