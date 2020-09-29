# vim:set ft=dockerfile:

# setup a template image
FROM centos:8 as template

# Default Env Variables
ENV MARIADB_VERSION=10.5
ENV MARIADB_ENTERPRISE_TOKEN=deaa8829-2a00-4b1a-a99c-847e772f6833

# build the replication UDFs
################################################################################
FROM template as udf_builder

# Change the workdir
WORKDIR /udf

# Install needed software to compile the UDF
ADD https://dlm.mariadb.com/enterprise-release-helpers/mariadb_es_repo_setup /tmp

RUN chmod +x /tmp/mariadb_es_repo_setup && \
    /tmp/mariadb_es_repo_setup --mariadb-server-version=${MARIADB_VERSION} --token=${MARIADB_ENTERPRISE_TOKEN} --apply

RUN dnf -y update && \
    dnf -y install gcc MariaDB-devel libcurl-devel

# Copy the UDF'es source
COPY replication_udf/* /udf/

# Compile the UDF
RUN gcc -fPIC -shared -o replication.so cJSON.c replication.c `mariadb_config --include` -lcurl -lm `mariadb_config --libs`

# compile pcre2grep as it's needed for HTAP's backup/restore
################################################################################
FROM template as pcre2grep-builder

USER root
WORKDIR /opt
ARG PCRE2_VERSION=10.35

# install the build dependencies
RUN dnf -y update && \
    dnf group install -y "Development Tools"

# compile pcre2grep
RUN curl https://ftp.pcre.org/pub/pcre/pcre2-${PCRE2_VERSION}.tar.gz -o pcre2.tar.gz && \
    tar -xf pcre2.tar.gz && \
    cd pcre2-${PCRE2_VERSION} && \
    ./configure --disable-shared --with-heap-limit=1024 --with-match-limit=500000 --with-match-limit-depth=5000 && \
    make && \
    cp pcre2grep /opt

# build the ColumnStore image
################################################################################
FROM template as main

# Default Env Variables
ENV TINI_VERSION=v0.18.0

# Add A SkySQL Specific PATH Entry
ENV PATH="/mnt/skysql/columnstore-container-scripts:${PATH}"

# Copy The Google Cloud SDK Repo To Image
COPY config/*.repo /etc/yum.repos.d/

# Update System
RUN dnf -y install epel-release && \
    dnf -y upgrade

# Install Some Dependencies
RUN dnf -y install bind-utils \
    bc \
    boost \
    cracklib \
    cracklib-dicts \
    expect \
    git \
    glibc-langpack-en \
    google-cloud-sdk \
    jemalloc \
    jq \
    less \
    libaio \
    monit \
    nano \
    net-tools \
    openssl \
    perl \
    perl-DBI \
    python3 \
    python3-requests \
    rsyslog \
    snappy \
    sudo \
    tcl \
    vim \
    wget

# Default Locale Variables
ENV LC_ALL=en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US.UTF-8

### BEGIN TEMPORARY BUILD

# Add MariaDB Repo
#ADD https://dlm.mariadb.com/enterprise-release-helpers/mariadb_es_repo_setup /tmp
#
#RUN chmod +x /tmp/mariadb_es_repo_setup && \
#    /tmp/mariadb_es_repo_setup --mariadb-server-version=${MARIADB_VERSION} --token=${MARIADB_ENTERPRISE_TOKEN} --apply

# Install MariaDB Packages
RUN dnf -y install \
     https://cspkg.s3.amazonaws.com/columnstore-1.5.4-1/push/781/centos8/MariaDB-shared-10.5.5_3-1.el8.x86_64.rpm \
     https://cspkg.s3.amazonaws.com/columnstore-1.5.4-1/push/781/centos8/MariaDB-common-10.5.5_3-1.el8.x86_64.rpm \
     https://cspkg.s3.amazonaws.com/columnstore-1.5.4-1/push/781/centos8/MariaDB-client-10.5.5_3-1.el8.x86_64.rpm \
     https://cspkg.s3.amazonaws.com/columnstore-1.5.4-1/push/781/centos8/MariaDB-server-10.5.5_3-1.el8.x86_64.rpm \
     https://cspkg.s3.amazonaws.com/columnstore-1.5.4-1/push/781/centos8/MariaDB-backup-10.5.5_3-1.el8.x86_64.rpm \
     https://cspkg.s3.amazonaws.com/columnstore-1.5.4-1/push/781/centos8/MariaDB-cracklib-password-check-10.5.5_3-1.el8.x86_64.rpm \
     https://cspkg.s3.amazonaws.com/columnstore-1.5.4-1/push/781/centos8/MariaDB-columnstore-engine-10.5.5_3-1.el8.x86_64.rpm

# Add, Unpack & Clean CMAPI Package
RUN mkdir -p /opt/cmapi
ADD https://cspkg.s3.amazonaws.com/cmapi/master/271/mariadb-columnstore-cmapi.tar.gz /opt/cmapi
WORKDIR /opt/cmapi
RUN tar -xvzf mariadb-columnstore-cmapi.tar.gz && \
    rm -f mariadb-columnstore-cmapi.tar.gz && \
    rm -rf /opt/cmapi/service*
WORKDIR /

### END TEMPORARY BUILD

# Copy Config Files & Scripts To Image
COPY config/etc/ /etc/

COPY config/.boto /root/.boto

COPY scripts/demo \
     scripts/columnstore-init \
     scripts/cmapi-start \
     scripts/cmapi-stop \
     scripts/cmapi-restart \
     scripts/columnstore-backup.sh \
     scripts/columnstore-restore.sh \
     scripts/htap-backup.sh \
     scripts/htap-restore.sh \
     scripts/skysql-specific-startup.sh \
     scripts/mcs-process /usr/bin/

COPY --from=udf_builder /udf/replication.so /usr/lib64/mysql/plugin/replication.so
COPY --from=pcre2grep-builder /opt/pcre2grep /usr/bin/pcre2grep

# Add Tini Init Process
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /usr/bin/tini

# Make Scripts Executable
RUN chmod +x /usr/bin/tini \
    /usr/bin/demo \
    /usr/bin/columnstore-init \
    /usr/bin/cmapi-start \
    /usr/bin/cmapi-stop \
    /usr/bin/cmapi-restart \
    /usr/bin/columnstore-backup.sh \
    /usr/bin/columnstore-restore.sh \
    /usr/bin/htap-backup.sh \
    /usr/bin/htap-restore.sh \
    /usr/bin/skysql-specific-startup.sh \
    /usr/bin/mcs-process

# Stream Edit Monit Config
RUN sed -i 's|set daemon\s.30|set daemon 5|g' /etc/monitrc && \
    sed -i 's|#.*with start delay\s.*240|  with start delay 60|' /etc/monitrc

# Add A Configuration Directory To my.cnf That Can Be Mounted By SkySQL & Disable The ed25519 Auth Plugin (DBAAS-2701)
RUN echo '!includedir /mnt/skysql/columnstore-container-configuration' >> /etc/my.cnf && \
    mkdir -p /mnt/skysql/columnstore-container-configuration && \
    touch /etc/my.cnf.d/mariadb-enterprise.cnf && \
    sed -i 's|plugin-load-add=auth_ed25519|#plugin-load-add=auth_ed25519|' /etc/my.cnf.d/mariadb-enterprise.cnf

# Create Persistent Volumes
VOLUME ["/etc/columnstore", "/var/lib/mysql", "/var/lib/columnstore"]

# Copy Entrypoint To Image
COPY scripts/docker-entrypoint.sh /usr/bin/

# Do Some Housekeeping
RUN chmod +x /usr/bin/docker-entrypoint.sh && \
    ln -s /usr/bin/docker-entrypoint.sh /docker-entrypoint.sh && \
    sed -i 's|SysSock.Use="off"|SysSock.Use="on"|' /etc/rsyslog.conf && \
    sed -i 's|^.*module(load="imjournal"|#module(load="imjournal"|g' /etc/rsyslog.conf && \
    sed -i 's|^.*StateFile="imjournal.state")|#  StateFile="imjournal.state")|g' /etc/rsyslog.conf && \
    dnf clean all && \
    rm -rf /var/cache/dnf && \
    find /var/log -type f -exec cp /dev/null {} \; && \
    cat /dev/null > ~/.bash_history && \
    history -c

# Bootstrap
ENTRYPOINT ["/usr/bin/tini","--","docker-entrypoint.sh"]
CMD cmapi-start && monit -I
