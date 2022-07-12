#!/bin/bash
# written by Hosein Yousefi <yousefi.hosein.o@gmail.com>
# GITHUB https://github.com/hosein-yousefii

# Automated script to replicate 2 instances of Mysql
# Default method is master-slave You are able to change
# the method by specifying it on the command line or
# with REPLICATION_METHOD variable.
# FORINSTANCE:
# export REPLICATION_METHOD=master-master



master-slave() {

	echo
	echo starting deploying...
	echo

	export FIRST_DB_NAME=${MYSQL_FIRST_DB_NAME:-'db-master'}
	export SECOND_DB_NAME=${MYSQL_SECOND_DB_NAME:-'db-slave'}

	export FIRST_REPL_USER=${MYSQL_FIRST_REPLICATION_USER:-'repl'}

	export FIRST_REPL_PASSWORD=${MYSQL_FIRST_REPLICATION_PASSWORD:-'qazwsx'}

	export FIRST_ROOT_PASSWORD=${MYSQL_FIRST_ROOT_PASS:-'qazwsx'}
	export SECOND_ROOT_PASSWORD=${MYSQL_SECOND_ROOT_PASS:-'qazwsx'}
	
	export FIRST_HOST=${MYSQL_FIRST_HOST:-'db-master'}
	export SECOND_HOST=${MYSQL_SECOND_HOST:-'db-slave'}
	
	export IP_ADDR=${DOCKER0_IP:-$(ip a show dev docker0 |grep inet|awk '{print $2}'|awk -F\/ '{print $1}'|grep -v ::)}

	docker-compose -f docker-compose-mysql.yaml up -d

	echo
	echo waiting 30s for containers to be up and running...
	echo Implementing mysql master slave replication...
	sleep 60
	echo

	# Create user on master database.
	docker exec $FIRST_HOST \
			mysql -u root --password=$FIRST_ROOT_PASSWORD \
			--execute="create user '$FIRST_REPL_USER'@'%' identified by '$FIRST_REPL_PASSWORD';\
			grant replication slave on *.* to '$FIRST_REPL_USER'@'%';\
			flush privileges;"


	# Get the log position and name.
	result=$(docker exec $FIRST_HOST mysql -u root --password=$FIRST_ROOT_PASSWORD --execute="show master status;")
	log=$(echo $result|awk '{print $6}')
	position=$(echo $result|awk '{print $7}')


	# Connect slave to master.
	docker exec $SECOND_HOST \
			mysql -u root --password=$SECOND_ROOT_PASSWORD \
			--execute="stop slave;\
			reset slave;\
			CHANGE MASTER TO MASTER_HOST='$FIRST_HOST', MASTER_USER='$FIRST_REPL_USER', \
			MASTER_PASSWORD='$FIRST_REPL_PASSWORD', MASTER_LOG_FILE='$log', MASTER_LOG_POS=$position;\
			start slave;\
			SHOW SLAVE STATUS\G;"

	echo
	echo in case of any errors, check if your containers up and running, then rerun this script.
	echo
	echo The master is running on $IP_ADDR:3306,  
	echo The slave is running on $IP_ADDR:3307.
	echo
}

master-master() {

        echo
        echo starting deploying...
	echo

        export FIRST_DB_NAME=${MYSQL_FIRST_DB_NAME:-'db-master1'}
        export SECOND_DB_NAME=${MYSQL_SECOND_DB_NAME:-'db-master2'}

        export SECOND_REPL_USER=${MYSQL_SECOND_REPLICATION_USER:-'repl-master2'}
        export FIRST_REPL_USER=${MYSQL_FIRST_REPLICATION_USER:-'repl-master1'}

        export FIRST_REPL_PASSWORD=${MYSQL_FIRST_REPLICATION_PASSWORD:-'qazwsx'}
        export SECOND_REPL_PASSWORD=${MYSQL_SECOND_REPLICATION_PASSWORD:-'qazwsx'}

        export FIRST_ROOT_PASSWORD=${MYSQL_FIRST_ROOT_PASS:-'qazwsx'}
        export SECOND_ROOT_PASSWORD=${MYSQL_SECOND_ROOT_PASS:-'qazwsx'}

        export FIRST_HOST=${MYSQL_FIRST_HOST:-'db-master1'}
        export SECOND_HOST=${MYSQL_SECOND_HOST:-'db-master2'}

        export IP_ADDR=${DOCKER0_IP:-$(ip a show dev docker0 |grep inet|awk '{print $2}'|awk -F\/ '{print $1}'|grep -v ::)}

        docker-compose -f docker-compose-mysql.yaml up -d

        echo
        echo waiting 30s for containers to be up and running...
	echo Implementing mysql master master replication...
        sleep 60
        echo

        # Create user on master database.
        docker exec $FIRST_HOST \
                        mysql -u root --password=$FIRST_ROOT_PASSWORD \
                        --execute="create user '$FIRST_REPL_USER'@'%' identified by '$FIRST_REPL_PASSWORD';\
                        grant replication slave on *.* to '$FIRST_REPL_USER'@'%';\
                        flush privileges;"

        docker exec $SECOND_HOST \
                        mysql -u root --password=$SECOND_ROOT_PASSWORD \
                        --execute="create user '$SECOND_REPL_USER'@'%' identified by '$SECOND_REPL_PASSWORD';\
                        grant replication slave on *.* to '$SECOND_REPL_USER'@'%';\
                        flush privileges;"


        # Get the log position and name.
        master1_result=$(docker exec $FIRST_HOST mysql -u root --password=$FIRST_ROOT_PASSWORD --execute="show master status;")
        master1_log=$(echo $master1_result|awk '{print $6}')
        master1_position=$(echo $master1_result|awk '{print $7}')


        master2_result=$(docker exec $SECOND_HOST mysql -u root --password=$SECOND_ROOT_PASSWORD --execute="show master status;")
        master2_log=$(echo $master2_result|awk '{print $6}')
        master2_position=$(echo $master2_result|awk '{print $7}')


        # Connect slave to master.
        docker exec $SECOND_HOST \
                        mysql -u root --password=$SECOND_ROOT_PASSWORD \
                        --execute="stop slave;\
                        reset slave;\
                        CHANGE MASTER TO MASTER_HOST='$FIRST_HOST', MASTER_USER='$FIRST_REPL_USER', \
                        MASTER_PASSWORD='$FIRST_REPL_PASSWORD', MASTER_LOG_FILE='$master1_log', MASTER_LOG_POS=$master1_position;\
                        start slave;\
                        SHOW SLAVE STATUS\G;"

        docker exec $FIRST_HOST \
                        mysql -u root --password=$FIRST_ROOT_PASSWORD \
                        --execute="stop slave;\
                        reset slave;\
                        CHANGE MASTER TO MASTER_HOST='$SECOND_HOST', MASTER_USER='$SECOND_REPL_USER', \
                        MASTER_PASSWORD='$SECOND_REPL_PASSWORD', MASTER_LOG_FILE='$master2_log', MASTER_LOG_POS=$master2_position;\
                        start slave;\
                        SHOW SLAVE STATUS\G;"

	sleep 2
	echo
	echo ###################	SECOND status

        docker exec $SECOND_HOST \
                        mysql -u root --password=$SECOND_ROOT_PASSWORD \
                        --execute="SHOW SLAVE STATUS\G;"

	sleep2
	echo
	echo ###################	FIRST status

        docker exec $FIRST_HOST \
                        mysql -u root --password=$FIRST_ROOT_PASSWORD \
                        --execute="SHOW SLAVE STATUS\G;"


	sleep 2
        echo
        echo in case of any errors, check if your containers up and running, then rerun this script.
        echo
        echo The masteir1 is running on $IP_ADDR:3306,
        echo The master2 is running on $IP_ADDR:3307.
        echo

}

METHOD=${REPLICATION_METHOD:-'master-slave'}


case ${METHOD} in

        master-master)
                master-master
        ;;

        master-slave)
                master-slave
        ;;

        *)
                echo """

 Automated script to replicate 2 instances of Mysql
 Default method is master-slave You are able to change
 the method by specifying it on the command line or
 with REPLICATION_METHOD variable.
 FORINSTANCE:
 export REPLICATION_METHOD=master-master

"""

        ;;

esac


