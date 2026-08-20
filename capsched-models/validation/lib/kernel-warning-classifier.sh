#!/usr/bin/env bash

# Collect kernel diagnostics without treating KCSAN's normal lifecycle notices
# as race reports.  Every other KCSAN-tagged line remains fail-closed.
capsched_collect_kernel_warning_reports()
{
	[ "$#" = 2 ] || return 2

	local serial=$1 report=$2 tmp
	local generic_regex='BUG:|WARNING:|Oops:|Kernel panic|KASAN:|possible recursive locking detected|possible circular locking dependency|inconsistent lock state|Invalid wait context|refcount_t:|ODEBUG:|rcu_preempt detected stalls|INFO: rcu|soft lockup|hard LOCKUP|hung_task|workqueue lockup|irq_work.*(stuck|failed|WARNING)|CPU hotplug.*(failed|stuck|rollback)|kmemleak:|unreferenced object|race at unknown origin|value changed: 0x[0-9a-f]+[[:space:]]*->[[:space:]]*0x[0-9a-f]+|Reported by Kernel Concurrency Sanitizer on:'

	[ -f "$serial" ] && [ ! -L "$serial" ] || return 2
	case "$report" in
		''|/) return 2 ;;
	esac
	tmp="${report}.tmp.$$"
	[ ! -e "$tmp" ] && [ ! -L "$tmp" ] || return 2
	if ! {
		grep -Eihn "$generic_regex" "$serial" || true
		awk '
		  {
		    raw = $0
		    sub(/\r$/, "", raw)
		    if (tolower(raw) !~ /kcsan:/)
		      next
		    normalized = raw
		    sub(/^[[:space:]]*\[[^]]+\][[:space:]]*/, "", normalized)
		    if (normalized == "kcsan: enabled early" ||
		        normalized == "kcsan: strict mode configured" ||
		        normalized ~ /^kcsan: selftest: [0-9]+\/[0-9]+ tests passed$/)
		      next
		    print NR ":" $0
		  }
		' "$serial"
	} | sort -t: -k1,1n -u > "$tmp"; then
		rm -f -- "$tmp"
		return 2
	fi
	if ! mv -- "$tmp" "$report"; then
		rm -f -- "$tmp"
		return 2
	fi
}
