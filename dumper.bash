#!/usr/bin/env bash

################################################################################
# maintainer: zeetabit                                                         #
# Copied from https://github.com/zeetabit/dumper                               #
################################################################################

echo "WELCOME to the DUMP DUMP DUMP utility."

################################################################################
# Helpers                                                                      #
################################################################################

trap "echo Exited!; exit;" SIGINT SIGTERM

Help() {
cat << EOL
Dump spryker tool, helps with testing at docker & development process.

Syntax: bash $(dirname "$0")/$(basename "$0") [-d|t|m|p|h]
options:
    d     Custom project directory, default: spryker-b2c or previously saved.
    t     Custom dump prefix, default: \`Y-m-d-H-i-\`.
    m     Mode, default: export. Available modes: export, e, import, i, none, n.
    s     SubMode, default: all. Available sub modes: broker, storage, database, search.
    p     Dumps path, default: {project_directory}/data/dumps. Should be under {project_directory}.
    c     Changes branch and makes export or import (depends on selected mode).

examples:
Make dump with prefix 'initial':
    bash data/dumps/dumper.bash -m export -t initial
    or:
    bash data/dumps/dumper.bash -m e -t initial
Restore from dump with prefix 'initial':
    bash data/dumps/dumper.bash -m import -t initial
    or:
    bash data/dumps/dumper.bash -m i -t initial
Change to development branch and restore from dump with 'initial' prefix:
    bash data/dumps/dumper.bash -m i -t initial -c development
Change to custom branch without import/export:
    bash data/dumps/dumper.bash -m n -c custom

EOL
}

declare -A availableModes=( [import]=import [i]=import [undump]=import [u]=import [input]=import [export]=export [e]=export [dump]=export [e]=export [d]=export [output]=export [o]=export [none]=none [n]=none [nothing]=none )
IllegalMode() {
cat << EOL
Illegal "mode" option value, available values:
    - Dump importing values: import, i, undump, u, input.
    - Make dump values: export, e, dump, d, output, o.
    - Do nothing: nothing, none, n.

EOL
}

declare -A availableSubModes=( [all]=all [broker]=broker [storage]=storage [database]=database [search]=search )
IllegalSubMode() {
cat << EOL
Illegal "sub mode" option value.

EOL
}


################################################################################
# Main program                                                                 #
################################################################################
startDirectory=${PWD}

unset opsPassed
while getopts d:t:m:p:s:c: flag
do
    case "${flag}" in
        d)
            directory=${OPTARG};
            opsPassed=1;;
        t)
            time=${OPTARG};
            opsPassed=1;;
        m)
            mode=${OPTARG};
            opsPassed=1;;
        p)
            dumpsPath=${OPTARG};
            opsPassed=1;;
        s)
            subMode=${OPTARG};
            opsPassed=1;;
        c)
            changeBranch=${OPTARG};
            opsPassed=1;;
        *) Help
           exit 1 ;;
    esac
done

if [ -z "$opsPassed" ]
then
   Help
   exit
fi

printf "Options is %s... " "$directory";
if [ -z "$directory" ]; then directory="spryker-b2c"; fi
if [ -z "$time" ]; then time=$(date +%Y-%m-%d-%H-%M); fi
if [ -z "$dumpsPath" ]; then dumpsPath="data/dumps"; fi
if [ -z "$subMode" ]; then subMode="all"; fi
if [[ ! -v availableModes[$mode] ]]; then IllegalMode; exit 1; fi
if [[ ! -v availableSubModes[$subMode] ]]; then IllegalSubMode; exit 1; fi
mode="${availableModes[$mode]}"
printf "ok\n";

if [[ $(dirname "$0") != "$dumpsPath" ]]; then echo "I can work only under data/dumps directory. Please move me to {spryker_project_path}/data/dumps directory, create directory if it not exists."; exit 1; fi

printf "Current directory is %s... " "$directory";
if [[ $directory != "${startDirectory: -${#directory}}"  ]]; then echo "You can call me only from spryker 'directory' path." && exit 1; fi
printf "ok\n";

deployPath=docker/deployment/default/deploy
[ ! -f $deployPath ] && echo "$deployPath does not exist. Did you install project before?" && exit 1;
CONTAINER_PREFIX_DEPLOY_LINE_PREFIX='readonly COMPOSE_PROJECT_NAME='
CONTAINER_PREFIX=$(sed -n -e "/^${CONTAINER_PREFIX_DEPLOY_LINE_PREFIX}/p" $deployPath)
CONTAINER_PREFIX="${CONTAINER_PREFIX//$CONTAINER_PREFIX_DEPLOY_LINE_PREFIX/}"

SPRYKER_STORES_DEPLOY_LINE_LOCAL_PREFIX='local STORES=('
SPRYKER_STORES_DEPLOY_LINE_PREFIX='readonly SPRYKER_STORES='
SPRYKER_STORES=$(sed -n -e "/^${SPRYKER_STORES_DEPLOY_LINE_PREFIX}/p" $deployPath)
SPRYKER_STORES="${SPRYKER_STORES//$SPRYKER_STORES_DEPLOY_LINE_PREFIX/}"
SPRYKER_STORES="${SPRYKER_STORES//*${SPRYKER_STORES_DEPLOY_LINE_LOCAL_PREFIX}/}"
SPRYKER_STORES=${SPRYKER_STORES%???}
IFS=" " read -r -a SPRYKER_STORES <<< "$SPRYKER_STORES"

if [ -z "$CONTAINER_PREFIX" ]
then
      echo "\$CONTAINER_PREFIX is empty. Exit."
      exit 1
fi

CONTAINER_BROKER=${CONTAINER_PREFIX}_broker_1
CONTAINER_STORE=${CONTAINER_PREFIX}_key_value_store_1
CONTAINER_DATABASE=${CONTAINER_PREFIX}_database_1
CONTAINER_SEARCH=${CONTAINER_PREFIX}_search_1
CONTAINER_CLI=${CONTAINER_PREFIX}_cli_1

printf "Containers status at %s namespace... " "$CONTAINER_PREFIX";
if [ ! "$(docker ps -aq -f name=$CONTAINER_BROKER)" ] | [ "$(docker ps -aq -f status=exited -f name=$CONTAINER_BROKER)" ]; then
    echo "$CONTAINER_BROKER is not found or not started, exit..."
    exit 1;
fi

if [ ! "$(docker ps -aq -f name=$CONTAINER_STORE)" ] | [ "$(docker ps -aq -f status=exited -f name=$CONTAINER_STORE)" ]; then
    echo "$CONTAINER_STORE is not found or not started, exit..."
    exit 1;
fi

if [ ! "$(docker ps -aq -f name=$CONTAINER_DATABASE)" ] | [ "$(docker ps -aq -f status=exited -f name=$CONTAINER_DATABASE)" ]; then
    echo "$CONTAINER_DATABASE is not found or not started, exit..."
    exit 1;
fi

if [ ! "$(docker ps -aq -f name=$CONTAINER_SEARCH)" ] | [ "$(docker ps -aq -f status=exited -f name=$CONTAINER_SEARCH)" ]; then
    echo "$CONTAINER_SEARCH is not found or not started, exit..."
    exit 1;
fi
printf "ok\n";

if [ ! -z "$changeBranch" ];
then
    printf  "changing to branch %s ... " "$changeBranch";
    git checkout "$changeBranch" || exit 1;
    printf "... regenerate transfers, propel::migrate ...";
    docker/sdk cli "composer install --prefer-dist && console transfer:e:g && console transfer:d:g && console transfer:g && console propel:migrate && console propel:migrate" &>> /dev/null
    printf  "ok\n";
fi

perActiveStore () {
    local command=$1
    local hideOutput=${2:-0}
    shift
    for storeName in "${SPRYKER_STORES[@]}"
    do
        printf '%s...' "$storeName"

        if [ "$hideOutput" == 1 ]; then
            APPLICATION_STORE="$storeName" $command &>> /dev/null
        else
            APPLICATION_STORE="$storeName" $command
        fi
    done
}

suspendScheduler () {
    printf "Stopping scheduler..."
    docker/sdk console 'scheduler:suspend' &>> /dev/null
    printf "done\n"
}

setupScheduler () {
    printf "Starting scheduler..."
    docker/sdk console 'scheduler:resume' &>> /dev/null
    printf "done\n"
}

suspendScheduler

printf "========> [%s] mode <=======\n" "$mode";

printf "= Broker...";
if [ "$subMode" == "all" ] && [ "$mode" != "none" ] || [ "$subMode" == "broker" ]  && [ "$mode" != "none" ];
then
    dumpFile="$dumpsPath"/"$time"-rabbitmq.tar.gz

    if [ "$mode" == "export" ]; then
        destination="$dumpsPath"/"$time"-rabbitmq
        printf ".. copy data to temporary dir..";
        rm -rf "$destination" &>> /dev/null
        docker cp "$CONTAINER_BROKER":/var/lib/rabbitmq/mnesia/rabbit@broker/msg_stores "$destination" || exit 1;
        printf "..pack as archive .."
        tar -zcvf "$dumpFile" "$destination" &>> /dev/null || exit 1;
        printf "..cleanup temporary dir.."
        rm -rf "$destination" || exit 1;
    elif [[ ! -f "$dumpFile" ]]; then
        printf "dump %s not found\n" "$dumpFile";
    else
        source="$dumpsPath"/"$time"-rabbitmq
        printf "..unpack backup data to temporary dir .."
        rm -rf "$source" &>> /dev/null
        tar -zxvf "$dumpFile" &>> /dev/null || exit 1
        printf "..cleanup container data.."
        docker exec -u root -it "$CONTAINER_BROKER" rm -rf /var/lib/rabbitmq/mnesia/rabbit@broker/msg_stores/ || exit 1
        printf "..put unpacked data from temporary dir to container.."
        docker cp "$source" "$CONTAINER_BROKER":/var/lib/rabbitmq/mnesia/rabbit@broker/msg_stores
        printf "..restart container.."
        docker restart "$CONTAINER_BROKER" &>> /dev/null || exit 1;
        printf "..cleanup temp dir.."
        rm -rf "$source"
    fi
    printf "ok\n";
else
    printf "skipped\n"
fi

printf "= Redis ...";
if [ "$subMode" == "all" ] && [ "$mode" != "none" ] || [ "$subMode" == "storage" ] && [ "$mode" != "none" ];
then
    dumpFile="$dumpsPath"/"$time"-redis.aof

    if [ "$mode" == "export" ]; then
        destination="$dumpsPath"/"$time"-redis.aof
        printf ".. copy data ..";
        docker cp "$CONTAINER_STORE":/data/appendonly.aof "$destination"
    elif [[ ! -f "$dumpFile" ]]; then
        printf "dump %s not found\n" "$dumpFile";
    else
        source="$dumpFile"
#        tail -f output | while read line; do
#          echo $line | grep 'Ready to accept connections' && break;
#        done
        printf "..put data to container.."
        docker cp "$source" "$CONTAINER_STORE":/data/appendonly.aof
        printf "..restart container.."
        docker restart "$CONTAINER_STORE" &>> /dev/null || exit 1;
    fi
    printf "ok\n";
else
    printf "skipped\n"
fi

printf "= Database ...";
if [ "$subMode" == "all" ] && [ "$mode" != "none" ] || [ "$subMode" == "database" ] && [ "$mode" != "none" ];
then
    dumpFile="$dumpsPath"/"$time"-mysql.sql
    dumpFileGz="$dumpFile".gz
    if [ "$mode" == "export" ]; then
        printf ".. permission folder change .."
        docker/sdk cli "mkdir -p $dumpsPath && chmod 0777 $dumpsPath" &>> /dev/null
        printf ".. dumping data ..";
        cmd1='mysqldump --user=${SPRYKER_DB_ROOT_USERNAME} --password=${SPRYKER_DB_ROOT_PASSWORD} --host=${SPRYKER_DB_HOST} --port=${SPRYKER_DB_PORT} --all-databases --add-drop-database > '"$dumpFile"
        docker/sdk cli "$cmd1" &>> /dev/null

        maxRetry=5
        counterCheck=0
        counterDumpAttempts=0
        while : ; do
            cmd="[ -f $dumpFile ]"
            cmd="$cmd"
            docker exec "$CONTAINER_CLI" $cmd && break
            printf " _Pausing until '$dumpFile' file in container '$CONTAINER_CLI' exists._ "
            sleep 1
            if [[ counterCheck -eq $maxRetry ]]
            then
                echo " __reached check attempt limit, try to dump one more time__ "
                docker/sdk cli "$cmd1"
                ((counterCheck=0))
                ((counterDumpAttempts++))
            fi
            [[ counterDumpAttempts -eq $maxRetry ]] && echo "reached dump attepmt limit, exit..." && exit 1
            ((counterCheck++))
        done

        if [[ ! -f "$startDirectory/$dumpFile" ]]
        then
            printf " _docker cp from container to host file path_ "
            docker cp "$CONTAINER_CLI:/data/$dumpFile" "$startDirectory/$dumpFile" &>> /dev/null || exit 1;
        fi

        gzip $dumpFile
    elif [[ ! -f "$dumpFileGz" ]]; then
        printf "dump %s not found\n" "$dumpFileGz" && exit 1;
    else
        source="$dumpFileGz"
        cmd="[ ! -f $source ]"
        cmd="$cmd"
        printf "..put dump to container.."
        docker cp "$startDirectory/$dumpFileGz" "$CONTAINER_CLI:/data/$dumpFileGz" &>> /dev/null || exit 1;
        printf "..restore data from dump to container.."
        cmd="gzip -dc $source"' | mysql --user=${SPRYKER_DB_ROOT_USERNAME} --password=${SPRYKER_DB_ROOT_PASSWORD} --host=${SPRYKER_DB_HOST} --port=${SPRYKER_DB_PORT}'
        docker/sdk cli "$cmd" &>> /dev/null
    fi
    printf "ok\n";
else
    printf "skipped\n"
fi

printf "= Search ...";
if [ "$subMode" == "all" ] && [ "$mode" != "none" ] || [ "$subMode" == "search" ] && [ "$mode" != "none" ];
then
    dumpFile="$dumpsPath"/"$time"-elasticsearch.tar.gz

    if [ "$mode" == "export" ]; then
        printf '.. (re)create snapshot repository ..'
        printf '_ curl delete _'
        curl -X DELETE "localhost:9200/_snapshot/loc?pretty" &>> /dev/null
        printf '_ rm folder _'
        docker exec -u 0 "$CONTAINER_SEARCH" rm -rf /usr/share/elasticsearch/data/snapshots/ &>> /dev/null || exit 1
        printf '_ cli register repository _'
        docker/sdk cli console elasticsearch:snapshot:register-repository loc &>> /dev/null
        printf '.. make snapshot, cli create snapshot ..'
        docker/sdk cli console search:snapshot:create loc "$time"-snapshot &>> /dev/null || exit 1;

        printf '.. wait while snapshot is processing (async operation) ..'
        while : ; do
            docker exec "$CONTAINER_SEARCH" [ -d "/usr/share/elasticsearch/data/snapshots/loc/indices" ] && break
            echo "Pausing until file in container exists."
            sleep 1
        done

        destination="$dumpsPath"/"$time"-elasticsearch
        printf ".. copy data to temporary dir..";
        rm -rf "$destination" &>> /dev/null
        docker cp "$CONTAINER_SEARCH":/usr/share/elasticsearch/data/snapshots/loc "$destination" &>> /dev/null || exit 1;
        printf "..pack as archive .."
        tar -zcvf "$dumpFile" "$destination" &>> /dev/null || exit 1;
        printf "..cleanup temporary dir.."
        rm -rf "$destination" || exit 1;


        printf "..cleanup container data.."
        curl -X DELETE "localhost:9200/_snapshot/loc?pretty" &>> /dev/null
    else
        printf '..cleanup container data, (re)create snapshot repository ..'
        curl -X DELETE "localhost:9200/_snapshot/loc?pretty" &>> /dev/null
        docker exec -u root -it "$CONTAINER_SEARCH" rm -rf /usr/share/elasticsearch/data/snapshots/ &>> /dev/null || exit 1
        docker/sdk cli console elasticsearch:snapshot:register-repository loc &>> /dev/null

        printf ".. delete EL indexes .."
        docker/sdk cli console elasticsearch:index:delete &>> /dev/null

        source="$dumpsPath"/"$time"-elasticsearch
        printf "..unpack backup data to temporary dir .."
        rm -rf "$source" &>> /dev/null
        tar -zxvf "$dumpFile" &>> /dev/null || exit 1

        printf "..put unpacked data from temporary dir to container.."
        docker cp "$source/." "$CONTAINER_SEARCH":/usr/share/elasticsearch/data/snapshots/loc &>> /dev/null
        printf "..cleanup temp dir.."
        rm -rf "$source"

        printf ".. restore snapshot .."
        docker/sdk cli console search:snapshot:restore loc "$time"-snapshot &>> /dev/null
    fi
    printf "ok\n";
else
    printf "skipped\n"
fi

setupScheduler

echo "=============> end <============"

echo "-t option prefix: ${time}"
echo "project directory: ${directory}"
echo "dumps directory: ${dumpsPath}"

echo
echo "See you!!"

