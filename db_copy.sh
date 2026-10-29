#!/bin/bash
set -euo pipefail

verbose=0
if [[ "${1:-}" == "-v" ]]; then
    verbose=1
    shift
fi

if [[ $# -lt 8 ]]; then
    echo "Usage: $0 [-v] <host1> <port1> <user1> <pass1> <host2> <port2> <user2> <pass2> [database]"
    exit 1
fi

src_host="$1"
src_port="$2"
src_user="$3"
src_pass="$4"
dst_host="$5"
dst_port="$6"
dst_user="$7"
dst_pass="$8"
database="${9:-}"

for name in src_host src_port src_user src_pass dst_host dst_port dst_user dst_pass; do
    if [[ -z "${!name//[[:space:]]/}" ]]; then
        echo "ERROR: $name is empty."
        exit 1
    fi
done

if (( verbose )) && [[ -z "$database" ]]; then
    echo "Source: $src_user@$src_host:$src_port (password: ${#src_pass} chars)"
    echo "Destination: $dst_user@$dst_host:$dst_port (password: ${#dst_pass} chars)"
fi

# Write credentials to a private option file, single-quoted so special
# characters in passwords are passed through verbatim.
cnf_quote() {
    local v="${1//\\/\\\\}"
    printf "'%s'" "${v//\'/\\\'}"
}

make_cnf() {
    local file
    file=$(mktemp)
    chmod 600 "$file"
    {
        echo "[client]"
        echo "host=$(cnf_quote "$1")"
        echo "port=$(cnf_quote "$2")"
        echo "user=$(cnf_quote "$3")"
        echo "password=$(cnf_quote "$4")"
    } > "$file"
    echo "$file"
}

src_cnf=$(make_cnf "$src_host" "$src_port" "$src_user" "$src_pass")
dst_cnf=$(make_cnf "$dst_host" "$dst_port" "$dst_user" "$dst_pass")
dump_file=""
trap 'rm -f "$src_cnf" "$dst_cnf" "$dump_file"' EXIT

# If no database was specified, retrieve all non-system databases.
if [[ -z "$database" ]]; then
    if (( verbose )); then
        echo "Retrieving database list from $src_host:$src_port..."
    fi

    databases=$(mariadb --defaults-extra-file="$src_cnf" \
        --batch --skip-column-names \
        -e "SHOW DATABASES;") || {
        echo "ERROR: Failed to retrieve database list (see error above)."
        exit 1
    }

    mapfile -t database_list < <(
        printf '%s\n' "$databases" |
        grep -Ev '^(information_schema|mysql|performance_schema|sys)$'
    )

    if [[ ${#database_list[@]} -eq 0 ]]; then
        echo "No databases found."
        exit 1
    fi

    verbose_flag=()
    (( verbose )) && verbose_flag=(-v)

    for db in "${database_list[@]}"; do
        [[ -z "$db" ]] && continue
        "$0" ${verbose_flag[@]+"${verbose_flag[@]}"} "$src_host" "$src_port" "$src_user" "$src_pass" \
            "$dst_host" "$dst_port" "$dst_user" "$dst_pass" "$db"
    done
    exit 0
fi

dump_file=$(mktemp)

(( verbose )) && echo "Dumping database '$database' from $src_host:$src_port..."

if (( verbose )); then
    mariadb-dump --defaults-extra-file="$src_cnf" \
        --single-transaction --routines --events --triggers \
        "$database" --verbose > "$dump_file"
else
    mariadb-dump --defaults-extra-file="$src_cnf" \
        --single-transaction --routines --events --triggers \
        "$database" > "$dump_file"
fi

(( verbose )) && echo "Restoring database '$database' to $dst_host:$dst_port..."

mariadb --defaults-extra-file="$dst_cnf" \
    -e "CREATE DATABASE IF NOT EXISTS \`$database\`;"

mariadb --defaults-extra-file="$dst_cnf" "$database" < "$dump_file"

(( verbose )) && echo "Successfully copied '$database'."
exit 0
