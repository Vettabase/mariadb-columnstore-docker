# vim:set ft=dockerfile:

FROM rockylinux:9 as base

RUN groupadd -r mysql && useradd -r -g mysql mysql --home-dir /var/lib/mysql
RUN mkdir /docker-entrypoint-initdb.d
ADD MariaDB.repo /etc/yum.repos.d/MariaDB.repo

RUN dnf update -yq
RUN dnf install -yq epel-release
RUN dnf upgrade -yq
RUN dnf install -yq MariaDB-server MariaDB-client MariaDB-columnstore-engine MariaDB-columnstore-cmapi MariaDB-s3-engine

# Define ENV Variables
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

#VOLUME ["/etc/columnstore","/etc/my.cnf.d","/var/lib/mysql","/var/lib/columnstore"]

COPY docker-entrypoint.sh /usr/local/bin/
ENTRYPOINT ["docker-entrypoint.sh"]
EXPOSE 3306
CMD ["mariadbd"]
