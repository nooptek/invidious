#!/bin/bash
set -eou pipefail

sed 's/\<UNLOGGED\>/TEMP/g' config/sql/*.sql |sqlite3 db.sqlite3

