#!/usr/bin/env bash

# Shared, side-effect-free controls for evidence runners that must bind exact
# input bytes and publish into a fresh per-run directory.

capsched_validate_run_id()
{
	case "$1" in
		''|.|..|[!A-Za-z0-9]*|*[!A-Za-z0-9._-]*)
			return 1
			;;
	esac
	return 0
}

capsched_sha256_file()
{
	sha256sum -- "$1" | awk '{print $1}'
}

capsched_verify_file_sha256()
{
	local input=$1
	local expected=$2
	local actual

	[ -f "$input" ] && [ ! -L "$input" ] || return 1
	actual=$(capsched_sha256_file "$input") || return 1
	[ "$actual" = "$expected" ]
}

capsched_create_fresh_run_dir()
{
	local root=$1
	local run_id=$2

	[ ! -L "$root" ] || return 1
	mkdir -p -- "$root" || return 1
	[ -d "$root" ] && [ ! -L "$root" ] || return 1
	mkdir -- "$root/$run_id" 2>/dev/null
}

capsched_snapshot_verified_file()
{
	local source=$1
	local expected=$2
	local destination=$3
	local partial="$destination.partial"

	[ -f "$source" ] && [ ! -L "$source" ] || return 1
	[ ! -e "$destination" ] && [ ! -L "$destination" ] || return 1
	[ ! -e "$partial" ] && [ ! -L "$partial" ] || return 1
	cp -- "$source" "$partial" || return 1
	capsched_verify_file_sha256 "$partial" "$expected" || return 1
	chmod 0444 -- "$partial" || return 1
	mv -- "$partial" "$destination"
}
