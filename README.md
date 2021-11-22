This tool can help you with making project's snapshot.
Tested only for development purporses.

Requirements:
- Installed spryker project.
- Docker with docker/sdk based deploy.
- Works only under project directory.

Installation:
`git clone git@github.com:zeetabit/dumper.git data/dumps`

For actual usage & examples see help section in `bash data/dumps/dumper.bash`

Examples:
1) make snaphot with `initial` prefix:
```
bash data/dumps/dumper.bash -m export -t initial
```
2) go to che `custom_branch` with rebuild transfer objects and propel:install:
```
bash data/dumps/dumper.bash -m none -c custom_branch
```
3) go to the initial branch, let's be `development` and restore the data from snapshot with `initial` prefix:
```
bash data/dumps/dumper.bash -m import -t initial -c development 
```
