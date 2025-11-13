#!/bin/bash

verbose=0
if [ "$1" = "-v" ]; then
    verbose=1
    shift
fi

if [ -z "${9}" ]; then
    echo "Usage: $0 [-v] <host1> <port1> <user1> <pass1> <host2> <port2> <user2> <pass2> <database1> [database2]"
    exit 1
fi

db2="${10:-$9}"

dump_file="database_dump.sql"
rm -f "$dump_file"

if [ $verbose -eq 1 ]; then
    echo "Dumping database '$9' from $1:$2..."
fi

# Use command arrays to handle quoting properly
dump_cmd=(mariadb-dump -h "$1" -P "$2" -u "$3" -p"$4" "$9")
if [ $verbose -eq 1 ]; then
    "${dump_cmd[@]}" --verbose > "$dump_file"
else
    "${dump_cmd[@]}" > "$dump_file"
fi

if [ $verbose -eq 1 ]; then
    echo "Restoring dump to database '$db2' on $5:$6..."
fi

restore_cmd=(mariadb -h "$5" -P "$6" -u "$7" -p"$8" "$db2")
if [ $verbose -eq 1 ]; then
    "${restore_cmd[@]}" --verbose < "$dump_file"
else
    "${restore_cmd[@]}" < "$dump_file"
fi

rm -f "$dump_file"

if [ $verbose -eq 1 ]; then
    echo "Cleanup complete."
fi
