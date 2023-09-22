#!/usr/bin/env bash

################################################################################
# maintainer: https://github.com/zeetabit                                      #
################################################################################

# Branch will be used as initial.
primaryBranch='development'
command="${1: -none}"
command="${command:1}"
secondOption="${2: -noneSecondOption}"
SPRYKER_HOOK_INSTALL_DEFAULT='vendor/bin/install -r production --no-ansi -vvv'

projectYmlPath='docker/deployment/default/project.yml'
if [[ -f $projectYmlPath ]]; then
    pipelineDefinitionPrefix="pipeline: "
    pipelineDefinitionPrefixReplace=""
    SPRYKER_HOOK_INSTALL_DEFAULT=$(grep "$pipelineDefinitionPrefix" $projectYmlPath)
    SPRYKER_HOOK_INSTALL_DEFAULT="${SPRYKER_HOOK_INSTALL_DEFAULT/${pipelineDefinitionPrefix}/${pipelineDefinitionPrefixReplace}}"
    SPRYKER_HOOK_INSTALL_DEFAULT="vendor/bin/install -r $SPRYKER_HOOK_INSTALL_DEFAULT --no-ansi -vvv"
fi

SPRYKER_HOOK_INSTALL="${SPRYKER_HOOK_INSTALL:=$SPRYKER_HOOK_INSTALL_DEFAULT}"

RED='\033[0;31m'
NC='\033[0m' # No Color

# trap ctrl-c and call ctrl_c()
trap ctrl_c INT

function ctrl_c() {
    echo 'I see you pushed ctrl+c, exit...'
    exit 1
}

echo "WELCOME to the QA utility."

################################################################################
# Helpers                                                                      #
################################################################################

Help() {
cat << EOL
QA tool, helps with testing at docker & development process.

Syntax: bash $(dirname "$0")/$(basename "$0") [-i|u|s|r]
options:
    i   Init project from scratch. If project exists - will delete everything.
        Create a snapshot.
        Works only for initial branches, for now it: $primaryBranch.
    u   Update initial branch state with latest code.
        Apply normal deploy.
        Create a snapshot.
    s   Switch to tested branch and initiate deploy. Works only when init is done.
        Changes branch.
        Performs cache cleanup, regenerates dynamic resources.
        Apply normal deploy.
    r   Rollback to initial branch: $primaryBranch.
        Switch back to '$primaryBranch' branch.
        Restores data snapshot to containers.
        Performs cache cleanup, regenerates dynamic resources.

examples:
Initial setup or project reset:
    bash qa.sh -i
Update initial setup with latest initial branch [$primaryBranch]:
    bash qa.sh -u
Test some branch
    bash qa.sh -s <branch_name>
    or if need to test current branch
    bash qa.sh -s
Move back to initial branch
    bash qa.sh -r

EOL
}

declare -A availableModes=( [init]=init [i]=init [update]=update [u]=update [switch]=switch [s]=switch [rollback]=rollback [r]=rollback )
################################################################################
# Main program                                                                 #
################################################################################
directory=${PWD}

if [[ ! -v availableModes["$command"] ]]; then Help; exit 1; fi
command="${availableModes[$command]}"

printf "Current directory is %s \n" "$directory";
printf "Command '%s' \n" "$command"
echo "oooooooooooooo> start <oooooooooooooo"

dumperDirPath="data/dumps";
dumperPath=$dumperDirPath/dumper.bash
dumperDistPath='./tests/dump_docker_data_to_logs_in_pipeline.sh'
[ ! -f $dumperDistPath ] && echo "[ERROR] dumper dist path not exists do use have installed project under this directory?" && exit 1;
[ ! -f $dumperPath ] && echo "[WARNING] dumper is not exists, copying initial one... " && cp $dumperDistPath $dumperPath;

warmup() {
    printf "Warmup ... \n"

    local currentBranch
    currentBranch="$(git branch --show-current)"

    echo -e "${RED}===]>${NC} composer install --prefer-dist"
    docker/sdk cli "composer install --prefer-dist"

    echo -e "${RED}===]>${NC} composer dump-autoload"
    docker/sdk cli "composer dump-autoload"

    local countFiles
    countFiles=$(git diff --name-status "$primaryBranch" | grep "src/" | grep "D   \|A     " | wc -l | tr -d '[:blank:]')
    countFiles=$(( $countFiles+0 ))
    if [ "$countFiles" -gt "0"  ] || [ "$currentBranch" == "$primaryBranch" ] || [ "$secondOption" == "-f" ]; then
        echo -e "${RED}===]>${NC} console cache:class-resolver:build"
        docker/sdk cli "console cache:class-resolver:build"
    fi

    echo -e "${RED}===]>${NC} console transfer:g && console transfer:d:g && console transfer:e:g"
    docker/sdk cli "console transfer:g && console transfer:d:g && console transfer:e:g"
    echo -e "${RED}===]>${NC} console cache:empty-all"
    docker/sdk cli "console cache:empty-all"
    echo -e "${RED}===]>${NC} $SPRYKER_HOOK_INSTALL"
    SPRYKER_HOOK_INSTALL=$SPRYKER_HOOK_INSTALL docker/sdk cli "$SPRYKER_HOOK_INSTALL"
    echo -e "${RED}===]>${NC} console q:w:s [3 workers]... wait"
    docker/sdk cli "console q:w:s& console q:w:s& console q:w:s& wait"
}

getCurrentSnapshot () {
    local currentBranch
    currentBranch="$(git branch --show-current)"
    currentBranch="${currentBranch////-}"

    echo "$currentBranch"
}

init () {
    printf "Starting init...\n"

    local currentBranch
    currentBranch="$(git branch --show-current)"
    local deployPath=docker/deployment/default/deploy
    [ $currentBranch != "$primaryBranch"  ] && [ "$secondOption" != "-f" ] && echo "[ERROR] I can init project only under primaryBranch: $primaryBranch. To force please add '-f'." && exit 1;
    [ ! -f $deployPath ] && echo "$deployPath does not exist. Did you boot project before by 'docker/sdk boot'?" && exit 1;

    echo "try to stop instance... wait"
    docker/sdk stop &>> /dev/null

    start=`date +%s`
    git clean -fdX -e \!.idea -e \!qa.sh -e \!data/dumps -e \!.npm -e \!vendor
    git clean -fdx -e .idea -e qa.sh -e data/dumps -e .npm -e vendor
    git stash
    git reset --hard HEAD
    took=$((`date +%s`-$start))
    echo "took $took sec"

    mkdir -p $dumperDirPath
    cp -R "$dumperDistPath" "$dumperPath"

    start=`date +%s`
    echo -e "${RED}===]>${NC} docker/sdk clean-data"
    docker/sdk clean-data
    took=$((`date +%s`-$start))
    echo "took $took sec"

    start=`date +%s`
    echo -e "${RED}===]>${NC} docker/sdk up"
    docker/sdk up
    took=$((`date +%s`-$start))
    echo "took $took sec"

    start=`date +%s`
    echo -e "${RED}===]>${NC} console q:w:s [3 workers]... wait"
    docker/sdk cli "console q:w:s& console q:w:s& console q:w:s& wait"
    took=$((`date +%s`-$start))
    echo "took $took sec"

    snapshot;
}

snapshot () {
    local currentSnapshot
    currentSnapshot="$(getCurrentSnapshot)"
    echo "make snapshot $currentSnapshot"
    echo -e "${RED}===]>${NC} bash $dumperDirPath/dumper.bash -m export -t $currentSnapshot"
    mkdir -p "$dumperDirPath/$currentSnapshot"
    rm -f $dumperDirPath/"$currentSnapshot"-mysql.sql.gz
    bash $dumperDirPath/dumper.bash -m export -t "$currentSnapshot"
}

snapshotRestore () {
    local currentSnapshot
    currentSnapshot="$(git branch --show-current)"
    echo "restore from snapshot $currentSnapshot"
    echo -e "${RED}===]>${NC} bash $dumperDirPath/dumper.bash -m import -t $currentSnapshot"
    bash $dumperDirPath/dumper.bash -m import -t "$currentSnapshot"
}

if [ "$command" == "init" ];
then
    init;
elif [ "$command" == "update" ];
then
    currentBranch="$(git branch --show-current)"
    [ $currentBranch != "$primaryBranch"  ] && [ "$secondOption" != "-f" ] && echo "[ERROR] I can update project only under primaryBranch: $primaryBranch. Please use additional '-f' to force." && exit 1;
    echo -e "${RED}===]>${NC} git pull -f"
    git pull -f
    warmup;
    snapshot;
elif [ "$command" == "switch" ];
then
    currentBranch="$(git branch --show-current)"
    expectedBranch=$secondOption
    if [ "$expectedBranch" == "noneSecondOption" ] || [ "$expectedBranch" == "" ];
    then
        expectedBranch=$currentBranch;
    fi;

    if [ "$expectedBranch" != "$currentBranch" ];
    then
        echo -e "${RED}===]>${NC} git checkout \"${expectedBranch}\" -f"
        git checkout "$expectedBranch" -f
    fi;

    echo -e "${RED}===]>${NC} git pull -f"
    git pull -f
    warmup;
elif [ "$command" == "rollback" ];
then
    currentBranch="$(git branch --show-current)"
    expectedBranch=$primaryBranch

    if [ "$expectedBranch" != "$currentBranch" ];
    then
        echo -e "${RED}===]>${NC} git checkout \"${expectedBranch}\" -f"
        git checkout "$expectedBranch" -f
    fi;

    snapshotRestore;
    echo -e "${RED}===]>${NC} git pull -f"
    git pull -f
    warmup;
fi


echo "oooooooooooooo> end <oooooooooooooo"

echo "directory: ${directory}"
echo "dumps directory: ${dumperDirPath}"

echo
echo "See you!!"
