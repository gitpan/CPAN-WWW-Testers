#!/usr/bin/bash

BASE=/opt/projects/cpantesters

cd $BASE/reports
mkdir -p logs

# build main site
perl bin/cpanreps-writepages -c=data/settings.ini -d=/var/www/cpanreps -t=../db/cpanstats.db >logs/cpanreps-writepages.log

# build heading images
perl bin/cpanreps-imlib -d=/var/www/cpanreps/headings -l=osnames.txt >logs/cpanreps-imlib.out

# verify all pages have been built
perl bin/cpanreps-verify -d=/var/www/cpanreps -t=../db/cpanstats.db >logs/cpanreps-verify.log
