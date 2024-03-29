# Spryker Data Dump Tool (Dumper)

This tool can help you with making project's snapshot.
Tested only for development purporses.

Requirements:
- Installed spryker project.
- Docker with docker/sdk based deploy.
- Works only under project directory (data/dumps).
- Works only with bash 5+.
- Tested only on Mac / Linux.

Installation:
`git clone git@github.com:zeetabit/dumper.git data/dumps`

For actual usage & examples see help section in `bash data/dumps/dumper.bash`

Examples:
1) make snaphot with `initial` prefix:
```
bash data/dumps/dumper.bash -m export -t initial
```
2) restore the data from snapshot with `initial` prefix:
```
bash data/dumps/dumper.bash -m import -t initial
```
3)  (can be installed by `wget https://raw.githubusercontent.com/zeetabit/dumper/main/qa.sh`) go to the `custom_branch` with rebuild transfer objects and propel:install:
```
bash qa.sh -s custom_branch
```
4)  (can be installed by `wget https://raw.githubusercontent.com/zeetabit/dumper/main/qa.sh`) go to the initial branch, let's be `development` and restore the data from snapshot with `development` prefix: 
```
bash qa.sh -r
```
5) use custom install hook for qa.sh; (can be installed by `wget https://raw.githubusercontent.com/zeetabit/dumper/main/qa.sh`)
```
SPRYKER_HOOK_INSTALL="vendor/bin/install -r some/custom/path --no-ansi -vvv" bash qa.sh -i
```
