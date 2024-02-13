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
		echo "ERROR USE_S3_STORAGE is set but missing S3_BUCKET"
        exit 1
	fi

	if [[ -n ${S3_REGION} ]] && [[ -z ${S3_HOSTNAME} ]]; then
		S3_CNF["s3_region"]=${S3_REGION}
        S3_ENDPOINT="${S3_ENDPOINT:-s3.${S3_REGION}.amazonaws.com}"
    elif [[ -n {$S3_HOSNAME} ]]; then
        S3_CNF["s3_host_name"]=${S3_HOSTNAME}
        S3_ENDPOINT=${S3_HOSTNAME}
	else
		echo "ERROR USE_S3_STORAGE is set but missing S3_REGION"
        exit 1
	fi

	if [[ -n ${S3_ACCESS_KEY} ]]; then
		S3_CNF["s3_access_key"]=${S3_ACCESS_KEY}
	else
		echo "ERROR USE_S3_STORAGE is set but missing S3_ACCESS_KEY"
        exit 1
	fi

	if [[ -n ${S3_SECRET_KEY} ]]; then
		S3_CNF["s3_secret_key"]=${S3_SECRET_KEY}
	else
		echo "ERROR USE_S3_STORAGE is set but missing S3_SECRET_KEY"
        exit 1
	fi

	# Custom S3 Compatible host
	if [[ -n ${S3_PORT} ]]; then
		if [[ -z ${S3_HOSTNAME} ]]; then
			echo "ERROR S3_PORT configured but Missing S3_HOSTNAME"
            exit 1
		fi
		S3_CNF["s3_port"]=${S3_PORT}
		S3_CNF["s3_use_http"]="ON"
	fi

	# Storage Manager endpoint URL and port
	if [[ -n ${S3_PORT} ]]; then
		S3_ENDPOINT_PORT="port_number = ${S3_PORT}"
    else
        S3_ENDPOINT_PORT=""
	fi

	S3_CONFIG_PATH="/etc/mysql/mariadb.conf.d/s3.cnf"
    echo "[mariadbd]" > $S3_CONFIG_PATH
    echo "plugin-maturity = alpha" >> $S3_CONFIG_PATH
	echo "plugin_load_add = ha_s3" >> $S3_CONFIG_PATH

	for section in "mariadb" "aria_s3_copy"; do
		echo "[${section}]" >> $S3_CONFIG_PATH
		for	S3_VAR in ${!S3_CNF[@]}; do
			echo "Setting ${S3_VAR}=${S3_CNF[$S3_VAR]} in section ${section}"
			echo "${S3_VAR}=${S3_CNF[$S3_VAR]}" >> $S3_CONFIG_PATH
		done
		echo "" >> $S3_CONFIG_PATH
	done

    cat $S3_CONFIG_PATH

    echo "Configuring StorageManager to use S3"
    mcsSetConfig Installation DBRootStorageType "StorageManager"
    mcsSetConfig StorageManager Enabled "Y"
    mcsSetConfig SystemConfig DataFilePlugin "libcloudio.so"
    sed -i "s|^service = LocalStorage|service = S3|" /etc/columnstore/storagemanager.cnf
    #sed -i "s|cache_size = 2g|cache_size = 4g|" /etc/columnstore/storagemanager.cnf
    if [[ -n ${S3_REGION} ]]; then
        sed -i "s|^region =.*|region = ${S3_REGION}|" /etc/columnstore/storagemanager.cnf
    fi
    sed -i "s|^bucket =.*|bucket = ${S3_BUCKET}|" /etc/columnstore/storagemanager.cnf
    sed -i "s|^# endpoint =.*|endpoint = ${S3_ENDPOINT}\n${S3_ENDPOINT_PORT}|" /etc/columnstore/storagemanager.cnf
    sed -i "s|^# aws_access_key_id =.*|aws_access_key_id = ${S3_ACCESS_KEY}|" /etc/columnstore/storagemanager.cnf
    sed -i "s|^# aws_secret_access_key =.*|aws_secret_access_key = ${S3_SECRET_KEY}|" /etc/columnstore/storagemanager.cnf
    if ! /usr/bin/testS3Connection >/var/log/mariadb/columnstore/testS3Connection.log 2>&1; then
        echo ""
        egrep -n '^service|^region|^bucket|^endpoint|^aws_*|^port_number' /etc/columnstore/storagemanager.cnf
        echo ""
        cat /var/log/mariadb/columnstore/testS3Connection.log 
		echo "Error: S3 Connectivity Failed"
        exit 1
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
    sleep 3
	controllernode &
    sleep 3
	PrimProc &
    sleep 3
	WriteEngineServer &
    sleep 3
	DMLProc &
    sleep 3
	DDLProc &
	sleep 5
	echo "Running Columnstore DB Builder"
	dbbuilder 7 mariadb #1> /tmp/dbbuilder.log
	#flock -u "$fd_lock"
	wait -n
}

mariadb_configure_columnstore
mariadb_configure_s3
mariadb_start_columnstore