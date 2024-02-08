#!/bin/bash

mariadb_configure_columnstore() {
	echo "Configuring Columnstore"
	#CS_CGROUP="${CS_CGROUP:-./}"
	#mcsSetConfig SystemConfig CGroup "${CS_CGROUP}"
	LANG_CNF=/etc/mysql/mariadb.conf.d/lang.cnf
	echo "[mariadbd]" > $LANG_CNF
	echo "collation_server=utf8_general_ci" >> $LANG_CNF
	echo "character_set_server=utf8" >> $LANG_CNF

	CROSSENGINEJOIN_USER="${CROSSENGINEJOIN_USER:-cross_engine_joiner}"
	CROSSENGINEJOIN_PASS="${CROSSENGINEJOIN_PASS:-$(pwgen --numerals --capitalize 32 1)}"

	mcsSetConfig CrossEngineSupport User ${CROSSENGINEJOIN_USER}
	mcsSetConfig CrossEngineSupport Password ${CROSSENGINEJOIN_PASS}
	mcsSetConfig CrossEngineSupport host "127.0.0.1"
}

mariadb_configure_s3() {
	if [[ -z ${USE_S3_STORAGE}  ]]; then
		echo "Missing USE_S3_STORAGE, Skipping S3 configuration"
		return
	fi

	echo "Configuring S3"

	declare -A S3_CNF
	S3_CNF["s3"]="ON"

	if [[ -n ${S3_BUCKET} ]]; then
		S3_CNF["s3_bucket"]=${S3_BUCKET}
	else
		mysql_error $"USE_S3_STORAGE is set but missing S3_BUCKET"
	fi

	if [[ -n ${S3_REGION} ]]; then
		S3_CNF["s3_region"]=${S3_REGION}
	else
		mysql_error $"USE_S3_STORAGE is set but missing S3_REGION"
	fi

	if [[ -n ${S3_ACCESS_KEY} ]]; then
		S3_CNF["s3_access_key"]=${S3_ACCESS_KEY}
	else
		mysql_error $"USE_S3_STORAGE is set but missing S3_ACCESS_KEY"
	fi

	if [[ -n ${S3_SECRET_KEY} ]]; then
		S3_CNF["s3_secret_key"]=${S3_SECRET_KEY}
	else
		mysql_error $"USE_S3_STORAGE is set but missing S3_SECRET_KEY"
	fi

	# Custom S3 Compatible host
	if [[ -n ${S3_HOSTNAME} ]]; then
		S3_CNF["s3_bucket"]=${S3_HOSTNAME}
	fi

	if [[ -n ${S3_PORT} ]]; then
		if [[ -z ${S3_HOSTNAME} ]]; then
			mysql_error $"S3_PORT configured but Missing S3_HOSTNAME"
		fi
		S3_CNF["s3_port"]=${S3_PORT}
		S3_CNF["s3_use_http"]="ON"
	fi

	# Storage Manager endpoint URL and port
	S3_ENDPOINT="${S3_ENDPOINT:-s3.${S3_REGION}.amazonaws.com}"
	S3_ENDPOINT_PORT=""
	if [[ -n ${S3_PORT} ]]; then
		S3_ENDPOINT_PORT="port_number = ${S3_PORT}"
	fi

	S3_CONFIG_PATH="/etc/mysql/mariadb.conf.d/s3.cnf"
	sed -i "s|^#plugin-maturity.*|plugin-maturity = alpha" $S3_CONFIG_PATH

	for section in "mariadb" "aria_s3_copy"; do
		echo "[${section}]" >> $S3_CONFIG_PATH
		for	S3_VAR in ${S3_CNF}; do
			echo "Setting ${S3_VAR} in section ${section}"
			echo "${S3_VAR}=${!S3_VAR}" >> $S3_CONFIG_PATH
		done
		echo "" >> $S3_CONFIG_PATH
	done

    echo "Configuring StorageManager to use S3"
    mcsSetConfig Installation DBRootStorageType "StorageManager"
    mcsSetConfig StorageManager Enabled "Y"
    mcsSetConfig SystemConfig DataFilePlugin "libcloudio.so"
    sed -i "s|service = LocalStorage|service = S3|" /etc/columnstore/storagemanager.cnf
    #sed -i "s|cache_size = 2g|cache_size = 4g|" /etc/columnstore/storagemanager.cnf
    sed -i "s|^service =.*|service = S3|" /etc/columnstore/storagemanager.cnf
    sed -i "s|^region =.*|region = ${S3_REGION}|" /etc/columnstore/storagemanager.cnf
    sed -i "s|^bucket =.*|bucket = ${S3_BUCKET}|" /etc/columnstore/storagemanager.cnf
    sed -i "s|^# endpoint =.*|endpoint = ${S3_ENDPOINT}\n${S3_PORT}|" /etc/columnstore/storagemanager.cnf
    sed -i "s|^# aws_access_key_id =.*|aws_access_key_id = ${S3_ACCESS_KEY_ID}|" /etc/columnstore/storagemanager.cnf
    sed -i "s|^# aws_secret_access_key =.*|aws_secret_access_key = ${S3_SECRET_ACCESS_KEY}|" /etc/columnstore/storagemanager.cnf
    if ! /usr/bin/testS3Connection >/var/log/mariadb/columnstore/testS3Connection.log 2>&1; then
		echo "Error: S3 Connectivity Failed"
    fi
}

mariadb_start_columnstore() {
	echo "Starting Columnstore"
	# prevent nodes using shared storage manager from stepping on each other when initializing
	# flock will open up an exclusive file lock to run atomic operations
	#exec {fd_lock}>/var/lib/columnstore/storagemanager/storagemanager-lock
	#flock -n "$fd_lock" || exit 0

	NODE_NUMBER="${NODE_NUMBER:-1}"
	MALLOC_CONF=''
	LD_PRELOAD=$(ldconfig -p | grep -m1 libjemalloc | awk '{print $1}')
	PYTHONPATH=/usr/share/columnstore/cmapi/deps
	DBRM_WORKER="DBRM_Worker${NODE_NUMBER}"
	echo "Columnstore Node Number is ${DBRM_WORKER}"
	workernode $DBRM_WORKER &
	controllernode &
	PrimProc &
	WriteEngineServer &
	DMLProc &
	DDLProc &
	#sleep 5
	#echo "Running Columnstore DB Builder"
	#dbbuilder 7 docker_process_sql #1> /tmp/dbbuilder.log
	#flock -u "$fd_lock"
	wait -n
}

mariadb_configure_columnstore
mariadb_configure_s3
mariadb_start_columnstore