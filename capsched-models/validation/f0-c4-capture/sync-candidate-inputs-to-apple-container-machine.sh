#!/usr/bin/env bash
set -euo pipefail

# Transfer only the exact tracked Candidate-4 inputs into root-owned VM-native
# storage.  The Apple Container machine does not need access to the macOS home
# directory or to an external-volume checkout.

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
repo_root=$(CDPATH= cd -- "$script_dir/../../.." && pwd -P)
readonly git=/usr/bin/git
readonly tar=/usr/bin/tar
readonly mktemp=/usr/bin/mktemp
readonly shasum=/usr/bin/shasum
readonly awk=/usr/bin/awk
readonly container=/usr/local/bin/container
readonly machine=domainlease-dev
readonly vm_state_root=/var/lib/domainlease-f0-c4
readonly vm_sources=$vm_state_root/sources
readonly vm_staging_root=$vm_state_root/source-staging

inputs=(
	f0-supervisor-c4-claim-registry-v1.json
	f0_supervisor_lts_v3.py
	f0_supervisor_orchestrator_v3.py
	run-f0-supervisor-v3-full.sh
	test-f0-supervisor-lts-v3-mutations.py
	test-f0-supervisor-orchestrator-v3-mutations.py
	test-run-f0-supervisor-v3-full.sh
	validate-f0-supervisor-lts-v3.py
)
paths=()
for name in "${inputs[@]}"; do
	paths+=("capsched-models/validation/$name")
done

for tool in "$git" "$tar" "$mktemp" "$shasum" "$awk" "$container"; do
	[[ -x $tool ]] || {
		printf 'error: pinned host tool missing: %s\n' "$tool" >&2
		exit 1
	}
done
[[ -z $($git -C "$repo_root" status --porcelain=v1 --untracked-files=all) ]] || {
	printf 'error: Candidate-4 source transfer requires a clean commit\n' >&2
	exit 1
}
commit=$($git -C "$repo_root" rev-parse --verify HEAD^{commit})
for path in "${paths[@]}"; do
	$git -C "$repo_root" ls-files --error-unmatch -- "$path" >/dev/null
done

host_tmp=$($mktemp -d "${TMPDIR:-/tmp}/domainlease-f0-c4-source.XXXXXX")
chmod 0700 "$host_tmp"
staging=
cleanup()
{
	/bin/rm -rf -- "$host_tmp"
	if [[ -n $staging ]]; then
		"$container" machine run --root -n "$machine" --workdir / -- \
			/bin/rm -rf -- "$staging" >/dev/null 2>&1 || true
	fi
}
trap cleanup EXIT HUP INT TERM

archive=$host_tmp/candidate-inputs.tar
$git -C "$repo_root" archive --format=tar --output="$archive" \
	"$commit" -- "${paths[@]}"
archive_sha=$($shasum -a 256 "$archive" | $awk '{print $1}')
destination=$vm_sources/$commit-$archive_sha
source_dir=$destination/capsched-models/validation

vm()
{
	"$container" machine run --root -n "$machine" --workdir / -- "$@"
}

vm /usr/bin/install -d -o root -g root -m 0700 \
	"$vm_state_root" "$vm_sources" "$vm_staging_root"
if ! vm /usr/bin/test -d "$destination"; then
	staging=$(vm /usr/bin/mktemp -d "$vm_staging_root/source.XXXXXX")
	"$container" machine run -i --root -n "$machine" --workdir / -- \
		/bin/tar --no-same-owner --no-same-permissions \
		-C "$staging" -xf - < "$archive"
	vm /bin/chown -R root:root "$staging"
	vm /bin/chmod -R a-w,go-rwx "$staging"
	for path in "${paths[@]}"; do
		vm /usr/bin/test -f "$staging/$path"
		vm /usr/bin/test ! -L "$staging/$path"
	done
	if vm /bin/mv -T "$staging" "$destination"; then
		staging=
	else
		vm /usr/bin/test -d "$destination"
	fi
	vm /bin/sync -f "$destination"
fi

for path in "${paths[@]}"; do
	vm /usr/bin/test -f "$destination/$path"
	vm /usr/bin/test ! -L "$destination/$path"
done
printf 'F0_C4_VM_NATIVE_SOURCE_SYNC_PASS commit=%s archive_sha256=%s path=%s\n' \
	"$commit" "$archive_sha" "$source_dir" >&2
printf '%s\n' "$source_dir"
