# vim:set ft=dockerfile:

# Setup A Template Image
FROM rockylinux:8

# Define Development ARGs
ARG VERSION=${VERSION}
ARG DEV=${DEV}
ARG MCS_REPO=${MCS_REPO}
ARG MCS_BASEURL=${MCS_BASEURL}
ARG CMAPI_REPO=${CMAPI_REPO}
ARG CMAPI_BASEURL=${CMAPI_BASEURL}
ARG SPIDER=${SPIDER}

# Define SkySQL Specific Path
ENV PATH="/mnt/skysql/columnstore-container-scripts:${PATH}"

# Add Google SDK Repo
RUN printf "%s\n" \
    "[google-cloud-sdk]" \
    "name=Google Cloud SDK" \
    "baseurl=https://packages.cloud.google.com/yum/repos/cloud-sdk-el8-$(uname -m)" \
    "enabled=1" \
    "gpgcheck=1" \
    "gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg" \
    "       https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg" > /etc/yum.repos.d/google-sdk.repo && \
    sed -i 's/arm64/aarch64/' /etc/yum.repos.d/google-sdk.repo

# Add Repo Setup Script
ADD .secrets scripts/repo /tmp/

# Choose Repo Version
RUN if [[ "${DEV}" == true ]]; then \
    printf "%s\n" \
    "[${MCS_REPO}]" \
    "name = ${MCS_REPO}" \
    "baseurl = ${MCS_BASEURL}" \
    "gpgcheck = 0" \
    "enabled = 1" \
    "module_hotfixes = 1" \
    "" \
    "[${CMAPI_REPO}]" \
    "name = ${CMAPI_REPO}" \
    "baseurl = ${CMAPI_BASEURL}" \
    "gpgcheck = 0" \
    "enabled = 1" \
    "module_hotfixes = 1" > /etc/yum.repos.d/engineering.repo; \
    else \
    bash /tmp/repo ${VERSION}; \
    fi

# Update System
RUN dnf -y install epel-release && \
    dnf -y upgrade

# Install Various Packages/Tools
RUN dnf -y install awscli \
    bind-utils \
    bc \
    boost \
    cracklib \
    cracklib-dicts \
    expect \
    gcc \
    git \
    glibc-langpack-en \
    google-cloud-sdk \
    htop \
    jemalloc \
    jq \
    less \
    libaio \
    libffi-devel \
    libxml2-devel \
    libxslt-devel \
    monit \
    nano \
    net-tools \
    openssl \
    perl \
    perl-DBI \
    procps-ng \
    redhat-lsb-core \
    rsync \
    rsyslog \
    snappy \
    sudo \
    tcl \
    tini \
    tzdata \
    vim \
    wget \
    xmlstarlet && \
    ln -s /usr/lib/lsb/init-functions /etc/init.d/functions && \
    sed -i 's/-n $\*$/-n $\* \\/' /etc/redhat-lsb/lsb_log_message && \
    rm -rf /usr/share/zoneinfo/tzdata.zi /usr/share/zoneinfo/leapseconds

# Define ENV Variables
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
ENV MCSBRANCH=${MCSBRANCH:-develop}
ENV CMAPIBRANCH=${CMAPIBRANCH:-develop}

# Install MariaDB Packages & Load Time Zone Info
RUN dnf -y install \
    MariaDB-shared \
    MariaDB-client \
    MariaDB-server \
    MariaDB-backup \
    MariaDB-cracklib-password-check && \
    rm -f /etc/my.cnf.d/spider.cnf && \
    cp /usr/share/mysql/mysql.server /etc/init.d/mariadb && \
    /etc/init.d/mariadb start && \
    mysql_tzinfo_to_sql /usr/share/zoneinfo | mariadb mysql && \
    /etc/init.d/mariadb stop && \
    dnf -y install MariaDB-columnstore-engine \
    MariaDB-columnstore-cmapi &&\
    if [[ "${SPIDER}" == true ]]; then \
    dnf -y install MariaDB-spider-engine; fi && \
    if [[ "${DEV}" == true ]]; then \
    dnf -y install MariaDB-test; fi

# Copy Config Files & Scripts To Image
COPY config/etc/ /etc/
COPY scripts/provision \
    scripts/provision-mxs \
    scripts/columnstore-init \
    scripts/mcs-start \
    scripts/mcs-stop \
    scripts/mcs-restart \
    scripts/skysql-specific-startup.sh \
    scripts/start-services /usr/bin/

# Make Scripts Executable
RUN chmod +x /usr/bin/provision \
    /usr/bin/provision-mxs \
    /usr/bin/columnstore-init \
    /usr/bin/mcs-start \
    /usr/bin/mcs-stop \
    /usr/bin/mcs-restart \
    /usr/bin/skysql-specific-startup.sh \
    /usr/bin/start-services

# Stream Edit Some Configs
RUN sed -i 's|set daemon\s.30|set daemon 5|g' /etc/monitrc && \
    sed -i 's|#.*with start delay\s.*240|  with start delay 60|' /etc/monitrc

# Add A Configuration Directory To my.cnf That Can Be Mounted By SkySQL & Disable The ed25519 Auth Plugin (DBAAS-2701)
RUN echo '!includedir /mnt/skysql/columnstore-container-configuration' >> /etc/my.cnf && \
    mkdir -p /mnt/skysql/columnstore-container-configuration && \
    touch /etc/my.cnf.d/mariadb-enterprise.cnf && \
    sed -i 's|plugin-load-add=auth_ed25519|#plugin-load-add=auth_ed25519|' /etc/my.cnf.d/mariadb-enterprise.cnf

# Customize cmapi_server.conf
RUN printf "%s\n" \
    "" \
    "[Dispatcher]" \
    "name = 'container'" \
    "path = '/usr/share/columnstore/cmapi/mcs_node_control/custom_dispatchers/container.sh'" \
    "" \
    "[application]" \
    "auto_failover = True" >> /etc/columnstore/cmapi_server.conf

# Make Copies Of MariaDB Related Folders
RUN /etc/init.d/mariadb stop && \
    rsync -Rravz --quiet /var/lib/mysql/ /var/lib/columnstore /etc/columnstore /etc/my.cnf.d /opt/ && \
    rm -f /opt/var/lib/mysql/mysql.sock

# Create Persistent Volumes
VOLUME ["/etc/columnstore", "/etc/my.cnf.d","/var/lib/mysql","/var/lib/columnstore"]

# Copy Entrypoint To Image
COPY scripts/docker-entrypoint.sh /usr/bin/

# Do Some Housekeeping
RUN chmod +x /usr/bin/docker-entrypoint.sh && \
    ln -s /usr/bin/docker-entrypoint.sh /docker-entrypoint.sh && \
    sed -i 's|SysSock.Use="off"|SysSock.Use="on"|' /etc/rsyslog.conf && \
    sed -i 's|^.*module(load="imjournal"|#module(load="imjournal"|g' /etc/rsyslog.conf && \
    sed -i 's|^.*StateFile="imjournal.state")|#  StateFile="imjournal.state")|g' /etc/rsyslog.conf && \
    dnf clean all && \
    find /var/log -type f -exec cp /dev/null {} \; && \
    rm -f /var/lib/mysql/*.err \
    /etc/yum.repos.d/mariadb.repo \
    /etc/yum.repos.d/engineering.repo \
    /tmp/.secrets \
    /tmp/repo && \
    rm -rf /var/cache/dnf && \
    cat /dev/null > ~/.bash_history && \
    history -c

# Bootstrap
ENTRYPOINT ["/usr/bin/tini","--","docker-entrypoint.sh"]
CMD ["start-services"]
