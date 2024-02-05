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
    glibc-langpack-en
RUN dnf upgrade -y
RUN dnf install -y MariaDB-server MariaDB-client 
RUN dnf install -y MariaDB-columnstore-engine MariaDB-s3-engine

# Define ENV Variables
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

#VOLUME ["/etc/columnstore","/etc/my.cnf.d","/var/lib/mysql","/var/lib/columnstore"]

COPY docker-entrypoint.sh /usr/local/bin/
USER mysql
ENTRYPOINT ["docker-entrypoint.sh"]
EXPOSE 3306
CMD ["mariadbd"]
