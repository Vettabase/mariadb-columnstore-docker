# vim:set ft=dockerfile:

FROM rockylinux:9 as base

RUN groupadd -r mysql && useradd -r -g mysql mysql --home-dir /var/lib/mysql
RUN mkdir /docker-entrypoint-initdb.d
ADD MariaDB.repo /etc/yum.repos.d/MariaDB.repo

RUN dnf update -y
RUN dnf install -y epel-release
RUN dnf install -y \
    bind-utils \
    procps-ng \
    glibc-langpack-en \
    pwgen \
    wget \
    tini
RUN dnf upgrade -y
RUN dnf install -y MariaDB-server MariaDB-client 
RUN dnf install -y MariaDB-columnstore-engine MariaDB-s3-engine

# add gosu for easy step-down from root
# https://github.com/tianon/gosu/releases
# gosu key is B42F6819007F00F88E364FD4036A9C25BF357DD4
ENV GOSU_VERSION 1.17
ENV GOSU_ARCH am64
RUN wget -q -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/${GOSU_VERSION}/gosu-${GOSU_ARCH}"; \
    wget -q -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/${GOSU_VERSION}/gosu-${GOSU_ARCH}.asc"; \
    GNUPGHOME="$(mktemp -d)"; \
    export GNUPGHOME; \
    gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4; \
    for key in $GPG_KEYS; do \
    gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "$key"; \
    done; \
    gpg --batch --export "$GPG_KEYS" > /etc/apt/trusted.gpg.d/mariadb.gpg; \
    if command -v gpgconf >/dev/null; then \
    gpgconf --kill all; \
    fi; \
    gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu; \
    gpgconf --kill all; \
    rm -rf "$GNUPGHOME" /usr/local/bin/gosu.asc;

# Define ENV Variables
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

#VOLUME ["/etc/columnstore","/etc/my.cnf.d","/var/lib/mysql","/var/lib/columnstore"]

RUN mkdir /docker-entrypint-initdb.d

COPY docker-entrypoint.sh /usr/local/bin/
ENTRYPOINT ["/usr/bin/tini","--","docker-entrypoint.sh"]
EXPOSE 3306
#USER mysql
CMD ["mariadbd"]
