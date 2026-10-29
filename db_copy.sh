#!/bin/bash
set -euo pipefail

verbose=0
with_users=0
only_users=0
while [[ "${1:-}" == -* ]]; do
    case "$1" in
        -v) verbose=1 ;;
        --with-users) with_users=1 ;;
        --only-users) only_users=1 ;;
        *) echo "ERROR: Unknown option '$1'."; exit 1 ;;
    esac
    shift
done

if (( with_users && only_users )); then
    echo "ERROR: --with-users and --only-users cannot be combined."
    exit 1
fi

if [[ $# -lt 8 ]]; then
    echo "Usage: $0 [-v] [--with-users | --only-users] <host1> <port1> <user1> <pass1> <host2> <port2> <user2> <pass2> [database]"
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

# Copy all user accounts and their grants from source to destination.
# System accounts and the two admin users running this script are skipped.
# Existing users on the destination are replaced so they match the source.
copy_users() {
    local accounts user account create grants sql="" count=0

    (( verbose )) && echo "Retrieving users from $src_host:$src_port..."

    accounts=$(mariadb --defaults-extra-file="$src_cnf" --batch --skip-column-names --raw \
        -e "SELECT User, CONCAT(QUOTE(User), '@', QUOTE(Host)) FROM mysql.user
            WHERE is_role = 'N'
              AND User NOT IN ('', 'root', 'mariadb.sys', 'mysql', 'healthcheck', 'PUBLIC');") || {
        echo "ERROR: Failed to list users. Does $src_user have SELECT on mysql.user?"
        return 1
    }

    while IFS=$'\t' read -r user account; do
        [[ -z "$user" || "$user" == "$src_user" || "$user" == "$dst_user" ]] && continue

        create=$(mariadb --defaults-extra-file="$src_cnf" --batch --skip-column-names --raw \
            -e "SHOW CREATE USER $account;") || {
            echo "ERROR: Failed to read user $account."
            return 1
        }
        grants=$(mariadb --defaults-extra-file="$src_cnf" --batch --skip-column-names --raw \
            -e "SHOW GRANTS FOR $account;") || {
            echo "ERROR: Failed to read grants for $account."
            return 1
        }

        sql+="${create/#CREATE USER/CREATE OR REPLACE USER};"$'\n'
        while IFS= read -r grant; do
            if [[ -n "$grant" ]]; then sql+="$grant;"$'\n'; fi
        done <<< "$grants"

        (( verbose )) && echo "Queued user $account."
        count=$((count + 1))
    done <<< "$accounts"

    if (( count == 0 )); then
        echo "No users to copy."
        return 0
    fi

    (( verbose )) && echo "Creating $count user(s) on $dst_host:$dst_port..."

    printf '%s' "$sql" | mariadb --defaults-extra-file="$dst_cnf" --force || {
        echo "ERROR: Some users or grants failed to apply (see errors above)."
        echo "       $dst_user needs CREATE USER and GRANT OPTION on the destination."
        return 1
    }

    echo "Copied $count user(s)."
}

if (( with_users || only_users )); then
    copy_users || exit 1
fi
(( only_users )) && exit 0

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

    # Copy up to max_jobs databases in parallel, prefixing output with the name.
    max_jobs=10
    running=0
    failed=0

    for db in "${database_list[@]}"; do
        [[ -z "$db" ]] && continue
        if (( running >= max_jobs )); then
            wait -n || failed=$((failed + 1))
            running=$((running - 1))
        fi
        "$0" ${verbose_flag[@]+"${verbose_flag[@]}"} "$src_host" "$src_port" "$src_user" "$src_pass" \
            "$dst_host" "$dst_port" "$dst_user" "$dst_pass" "$db" 2>&1 |
            awk -v prefix="[$db] " '{ print prefix $0; fflush() }' &
        running=$((running + 1))
    done

    while (( running > 0 )); do
        wait -n || failed=$((failed + 1))
        running=$((running - 1))
    done

    if (( failed > 0 )); then
        echo "ERROR: $failed database(s) failed to copy."
        exit 1
    fi
    echo "All databases copied."
    exit 0
fi

dump_file=$(mktemp)

(( verbose )) && echo "Dumping database '$database' from $src_host:$src_port..."

dump_args=(--single-transaction --routines --events --triggers)
(( verbose )) && dump_args+=(--verbose)

dump_err=$(mktemp)
trap 'rm -f "$src_cnf" "$dst_cnf" "$dump_file" "$dump_err"' EXIT

if ! mariadb-dump --defaults-extra-file="$src_cnf" "${dump_args[@]}" \
        "$database" > "$dump_file" 2> "$dump_err"; then
    if grep -q 'Got error: 1049' "$dump_err"; then
        echo "WARNING: Database '$database' not found on source, skipping."
        exit 0
    fi
    cat "$dump_err" >&2
    echo "ERROR: Failed to dump '$database'."
    exit 1
fi
(( verbose )) && cat "$dump_err" >&2

(( verbose )) && echo "Restoring database '$database' to $dst_host:$dst_port..."

mariadb --defaults-extra-file="$dst_cnf" \
    -e "CREATE DATABASE IF NOT EXISTS \`$database\`;"

mariadb --defaults-extra-file="$dst_cnf" "$database" < "$dump_file"

(( verbose )) && echo "Successfully copied '$database'."
exit 0
