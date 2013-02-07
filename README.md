gitolite-hipchat-notification
==============================

Original adapted heavily from: https://github.com/LegionSB/gitolite-campfire-notification
This one forked from https://github.com/peplin/gitolite-hipchat-notification

Installation
------------

Currently you can either install the script at a global level which will mean the config
is the same for all repositories, or you can install in each individual repository.

Issue #1 is to change the config to use gitolite / git config so that the standard
gitolite config files / repo can be used to configure the HipChat settings on a per-repo
basis.

### For a global Install

This will install the same hook for all your repositories with the same configuration.

1. Copy files to your gitolite user's .gitolite/hooks/common folder
2. Rename config.yml.example to config.yml, and fill in your Hipchat account information
3. Re-run "gl-setup" to propogate the hooks to each repo's hook folder

### For a custom install per repo

To have different configs for different repos (eg. if you want to notify a different room) then
you need to manually install the files into your repo.

1. Copy files into your gitolite user's repositories/REPO/hooks folder
2. Rename config.yml.example to config.yml, and fill in your Hipchat account information