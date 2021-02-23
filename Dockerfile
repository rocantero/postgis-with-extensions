FROM postgis/postgis:latest as base-image

ENV ORACLE_HOME=/usr/lib/oracle/client
ENV PATH $PATH:${ORACLE_HOME}


FROM base-image as common-deps

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        wget \
        ca-certificates \
        make \
        gcc \
        postgresql-server-dev-$PG_MAJOR


FROM common-deps as build-oracle_fdw

# Latest version
#ARG ORACLE_CLIENT_URL=https://download.oracle.com/otn_software/linux/instantclient/instantclient-basic-linuxx64.zip
#ARG ORACLE_SQLPLUS_URL=https://download.oracle.com/otn_software/linux/instantclient/instantclient-sqlplus-linuxx64.zip
#ARG ORACLE_SDK_URL=https://download.oracle.com/otn_software/linux/instantclient/instantclient-sdk-linuxx64.zip

# Make sure the Oracle client's version being used is in oracle_fdw's Makefile's PG_CPPFLAGS and SHLIB_LINK variables
# https://github.com/laurenz/oracle_fdw/blob/master/Makefile

# Version specific setup
#ARG ORACLE_CLIENT_VERSION=21.1.0.0.0
#ARG ORACLE_CLIENT_PATH=211000
ARG ORACLE_CLIENT_VERSION=19.8.0.0.0
ARG ORACLE_CLIENT_PATH=19800
ARG ORACLE_CLIENT_URL=https://download.oracle.com/otn_software/linux/instantclient/${ORACLE_CLIENT_PATH}/instantclient-basic-linux.x64-${ORACLE_CLIENT_VERSION}dbru.zip
ARG ORACLE_SQLPLUS_URL=https://download.oracle.com/otn_software/linux/instantclient/${ORACLE_CLIENT_PATH}/instantclient-sqlplus-linux.x64-${ORACLE_CLIENT_VERSION}dbru.zip
ARG ORACLE_SDK_URL=https://download.oracle.com/otn_software/linux/instantclient/${ORACLE_CLIENT_PATH}/instantclient-sdk-linux.x64-${ORACLE_CLIENT_VERSION}dbru.zip


RUN apt-get update && \
    apt-get install -y --no-install-recommends unzip && \
    # instant client
    wget -O instant_client.zip ${ORACLE_CLIENT_URL} && \
    unzip instant_client.zip && \
    # sqlplus
    wget -O sqlplus.zip ${ORACLE_SQLPLUS_URL} && \
    unzip sqlplus.zip && \
    # sdk
    wget -O sdk.zip ${ORACLE_SDK_URL} && \
    unzip sdk.zip && \
    # install
    mkdir -p ${ORACLE_HOME} && \
    mv instantclient*/* ${ORACLE_HOME}

# Install oracle_fdw
ARG ORACLE_FDW_VERSION=2_3_0
ARG ORACLE_FDW_URL=https://github.com/laurenz/oracle_fdw/archive/ORACLE_FDW_${ORACLE_FDW_VERSION}.tar.gz
ARG SOURCE_FILES=/tmp/oracle_fdw

WORKDIR ${SOURCE_FILES}
RUN apt-get update && \
    apt-get install -y --no-install-recommends libaio1 && \
    wget -O - ${ORACLE_FDW_URL} | tar -zx --strip-components=1 -C . && \
    make && \
    make install && \
    echo ${ORACLE_HOME} > /etc/ld.so.conf.d/oracle_instantclient.conf && \
    ldconfig




FROM common-deps as build-sqlite_fdw

ARG SQLITE_FDW_VERSION=1.3.1
ARG SQLITE_FDW_URL=https://github.com/pgspider/sqlite_fdw/archive/v${SQLITE_FDW_VERSION}.tar.gz
ARG SOURCE_FILES=/tmp/sqlite_fdw

WORKDIR ${SOURCE_FILES}
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        libsqlite3-dev \
        cmake \
        pkg-config \
        libssl-dev \
        libzstd-dev && \
    wget -O - ${SQLITE_FDW_URL} | tar -zx -C . --strip-components=1 && \
    make USE_PGXS=1 && \
    make USE_PGXS=1 install




FROM base-image as merge-pipeline

# See the "Locale Customization" section at https://github.com/docker-library/docs/blob/master/postgres/README.md
RUN localedef -i pt_BR -c -f UTF-8 -A /usr/share/locale/locale.alias pt_BR.UTF-8
ENV LANG pt_BR.utf8

# lc-collate=C makes strings comparison (and decurring operations like sorting) faster,
#     because it's just byte-to-byte comparison (no complex locale rules)
# lc-ctype=C would make Postgres features that use ctype.h (e.g. upper(), lower(), initcap(), ILIKE, citext)
#     work as expected only for characters in the US-ASCII range (that is, up to codepoint 0x7F in Unicode).
ENV POSTGRES_INITDB_ARGS " \
	-E utf8 \
	--auth-host=md5 \
	--lc-collate=C \
	--lc-ctype=pt_BR.UTF-8 \
	--lc-messages=pt_BR.UTF-8 \
	--lc-monetary=pt_BR.UTF-8 \
	--lc-numeric=pt_BR.UTF-8 \
	--lc-time=pt_BR.UTF-8 \
"

# Install pg_cron, mysql_fdw, ogr_fdw, orafce, pgaudit, pgpcre, pgtap, pldebugger, plpgsql_check, tds_fdw and plpython3
# libaio1 is a runtime requirement for the Oracle client that oracle_fdw uses
# I think libsqlite3-dev is a runtime requirement for sqlite_fdw
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        libaio1 \
        libsqlite3-dev \
        postgresql-$PG_MAJOR-cron \
        postgresql-$PG_MAJOR-mysql-fdw \
        postgresql-$PG_MAJOR-ogr-fdw \
        postgresql-$PG_MAJOR-orafce \
        postgresql-$PG_MAJOR-pgaudit \
        postgresql-$PG_MAJOR-pgpcre \
        postgresql-$PG_MAJOR-pgtap \
        postgresql-$PG_MAJOR-pldebugger \
        postgresql-$PG_MAJOR-plpgsql-check \
        postgresql-$PG_MAJOR-tds-fdw \
        postgresql-plpython3-$PG_MAJOR && \
    apt-get purge -y --auto-remove


COPY --from=build-oracle_fdw ${ORACLE_HOME} ${ORACLE_HOME}
COPY --from=build-oracle_fdw /etc/ld.so.conf.d/oracle_instantclient.conf /etc/ld.so.conf.d/oracle_instantclient.conf
COPY --from=build-oracle_fdw /usr/lib/postgresql/$PG_MAJOR/lib/oracle_fdw.so /usr/lib/postgresql/$PG_MAJOR/lib/oracle_fdw.so
COPY --from=build-oracle_fdw /usr/share/doc/postgresql-doc-$PG_MAJOR/extension/README.oracle_fdw /usr/share/doc/postgresql-doc-$PG_MAJOR/extension/README.oracle_fdw
COPY --from=build-oracle_fdw /usr/share/postgresql/$PG_MAJOR/extension/oracle_fdw* /usr/share/postgresql/$PG_MAJOR/extension/


# TO-DO:
# Find out which other modifications each extension requires me to do, like changing something on postgresql.conf (looking at you, pg_cron)
#   See the "Database Configuration" section at https://github.com/docker-library/docs/blob/master/postgres/README.md
# Use initialization scripts to create the database, roles etc at build-time
#   See the "Initialization scripts" section at https://github.com/docker-library/docs/blob/master/postgres/README.md



