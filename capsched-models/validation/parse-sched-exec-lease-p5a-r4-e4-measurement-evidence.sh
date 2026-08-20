#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C

if [ "$#" -ne 3 ]; then
	printf 'usage: %s RESULT_ROWS SUMMARY_ROWS OUTPUT_DIRECTORY\n' "$0" >&2
	exit 2
fi

ROWS=$1
SUMMARIES=$2
OUT=$3
GUEST_VCPUS=${GUEST_VCPUS:-2}

die()
{
	printf 'error: %s\n' "$*" >&2
	exit 1
}

for command in awk cmp cut jq mkdir sort tail wc; do
	command -v "$command" >/dev/null 2>&1 || die "missing command: $command"
done
case "$GUEST_VCPUS" in
	''|*[!0-9]*) die 'GUEST_VCPUS must be a positive integer' ;;
	0) die 'GUEST_VCPUS must be greater than zero' ;;
esac
for input in "$ROWS" "$SUMMARIES"; do
	[ -f "$input" ] || die "input is not a regular file: $input"
	[ ! -L "$input" ] || die "input must not be a symlink: $input"
done
if [ -e "$OUT" ] || [ -L "$OUT" ]; then
	die "output already exists: $OUT"
fi
mkdir "$OUT"

TABLE="$OUT/measurements.tsv"
EXPECTED="$OUT/expected-cells.txt"
ACTUAL="$OUT/actual-cells.txt"
SUMMARY_TABLE="$OUT/summaries.tsv"
DERIVED_SUMMARY="$OUT/derived-summaries.tsv"
FAILURES="$OUT/threshold-failures.tsv"

[ "$(wc -l < "$ROWS" | tr -d ' ')" = 682 ] \
	|| die 'R4-E4 result row count is not exactly 682'

awk -v guest_vcpus="$GUEST_VCPUS" '
function fail(code, message) {
  print "row-parser: " message > "/dev/stderr";
  parser_status=code;
  exit code;
}
function integer(key) {
  if (!(key in value) || value[key] !~ /^[0-9]+$/)
    fail(20, "missing or non-numeric " key " at row " NR);
  return value[key] + 0;
}
function enum_value(key, expression) {
  if (!(key in value) || value[key] !~ expression)
    fail(21, "invalid " key " at row " NR);
  return value[key];
}
function permit(key) { allowed[key]=1 }
function stats(prefix,    a,b,c,d,e,f) {
  a=integer(prefix "_min"); b=integer(prefix "_p50");
  c=integer(prefix "_p95"); d=integer(prefix "_p99");
  e=integer(prefix "_p999"); f=integer(prefix "_max");
  if (!(a <= b && b <= c && c <= d && d <= e && e <= f))
    fail(22, "non-monotonic " prefix " statistics at row " NR);
}
BEGIN {
  OFS="\t";
  print "family","key","samples","warmups","operations","measurement_cpu","cpu_migrations","control_irqs_disabled","treatment_irqs_disabled","control_preempt_depth","treatment_preempt_depth","state_errors","harness_errors","control_min","control_p50","control_p95","control_p99","control_p999","control_max","treatment_min","treatment_p50","treatment_p95","treatment_p99","treatment_p999","treatment_max","additional_min","additional_p50","additional_p95","additional_p99","additional_p999","additional_max","async_min","async_p50","async_p95","async_p99","async_p999","async_max","local_gate","async_gate","recomputed_local_gate","recomputed_async_gate","rejected";
  base="family samples warmups operations measurement_cpu cpu_migrations control_irqs_disabled treatment_irqs_disabled control_preempt_depth treatment_preempt_depth state_errors harness_errors local_gate async_gate";
  metric_prefixes="control treatment additional async";
  metric_suffixes="min p50 p95 p99 p999 max";
}
{
  if ($1 != "R4_E4_RESULT") fail(2, "bad row marker at row " NR);
  delete value; delete seen; delete allowed;
  for (i=2; i<=NF; i++) {
    at=index($i, "=");
    if (!at) fail(3, "token without equals at row " NR);
    key=substr($i,1,at-1); val=substr($i,at+1);
    if (key == "" || val == "" || seen[key]++)
      fail(4, "empty or duplicate key at row " NR);
    value[key]=val;
  }
  n=split(base, list, " "); for (i=1;i<=n;i++) permit(list[i]);
  np=split(metric_prefixes, prefixes, " ");
  ns=split(metric_suffixes, suffixes, " ");
  for (i=1;i<=np;i++) for (j=1;j<=ns;j++) permit(prefixes[i] "_" suffixes[j]);

  family=enum_value("family", "^(publication|picker_kick|irq_dispatch|recovery|notifier|current_stop|offline)$");
  if (family == "publication") {
    permit("active_rqs"); permit("occupancy"); permit("inner"); permit("burst"); permit("owner");
    a=enum_value("active_rqs", "^(0|1|2)$"); o=enum_value("occupancy", "^(1|8|32|64)$");
    n=enum_value("inner", "^(0|1|64|4096)$"); b=enum_value("burst", "^(1|64|4096)$");
    owner=enum_value("owner", "^(clear|owned_restart)$");
    cell=family ":" a ":" o ":" n ":" b ":" owner;
  } else if (family == "picker_kick") {
    permit("occupancy"); permit("inner"); permit("burst"); permit("owner");
    o=enum_value("occupancy", "^(1|8|32|64)$"); n=enum_value("inner", "^(0|1|64|4096)$");
    b=enum_value("burst", "^(1|64|4096)$"); owner=enum_value("owner", "^(idle|dirty_irq_pending|work_running)$");
    cell=family ":" o ":" n ":" b ":" owner;
  } else if (family == "irq_dispatch") {
    permit("queue_work"); permit("unrelated_depth");
    outcome=enum_value("queue_work", "^(queued|false_pending|false_running)$");
    depth=enum_value("unrelated_depth", "^(0|1|64)$");
    cell=family ":" outcome ":" depth;
  } else if (family == "recovery") {
    permit("dirty_depth"); permit("occupancy"); permit("class"); permit("outcome");
    depth=enum_value("dirty_depth", "^(1|8|32|64)$"); o=enum_value("occupancy", "^(1|8|32|64)$");
    class=enum_value("class", "^(queued|delayed|current)$"); outcome=enum_value("outcome", "^(settle|republished_race|blocked)$");
    cell=family ":" depth ":" o ":" class ":" outcome;
  } else if (family == "notifier") {
    permit("active_rqs"); permit("cursor"); permit("membership"); permit("class"); permit("owner");
    a=enum_value("active_rqs", "^(1|2)$"); cursor=enum_value("cursor", "^(first|last|end_of_pass)$");
    membership=enum_value("membership", "^(stable|changed_restart)$"); class=enum_value("class", "^(queued|current)$");
    owner=enum_value("owner", "^(idle|coalesced)$");
    cell=family ":" a ":" cursor ":" membership ":" class ":" owner;
  } else if (family == "current_stop") {
    permit("source"); permit("observation"); permit("owner"); permit("burst");
    source=enum_value("source", "^(recovery|notifier)$");
    observation=enum_value("observation", "^(current_changed|same_current_revalidated)$");
    owner=enum_value("owner", "^(idle|coalesced)$"); b=enum_value("burst", "^(1|64|4096)$");
    cell=family ":" source ":" observation ":" owner ":" b;
  } else {
    permit("occupancy"); permit("callback");
    o=enum_value("occupancy", "^(0|1|8|32|64)$");
    callback=enum_value("callback", "^(idle|irq_pending|work_pending|work_running|self_requeue)$");
    cell=family ":" o ":" callback;
  }
  for (key in seen) if (!(key in allowed)) fail(5, "unexpected key " key " at row " NR);
  for (key in allowed) if (!(key in seen)) fail(6, "missing key " key " at row " NR);
  if (cell_seen[cell]++) fail(7, "duplicate cell " cell);

  samples=integer("samples"); warmups=integer("warmups"); operations=integer("operations");
  measurement_cpu=integer("measurement_cpu"); migrations=integer("cpu_migrations");
  control_irq=integer("control_irqs_disabled"); treatment_irq=integer("treatment_irqs_disabled");
  control_preempt=integer("control_preempt_depth"); treatment_preempt=integer("treatment_preempt_depth");
  state_errors=integer("state_errors"); harness_errors=integer("harness_errors");
  if (samples != 10000 || warmups != 256) fail(8, "sample or warmup count changed at row " NR);
  expected_operations = family == "offline" ? o + 0 : 1;
  if (operations != expected_operations) fail(9, "operation count changed at row " NR);
  if (measurement_cpu < 0 || measurement_cpu >= guest_vcpus) fail(10, "measurement CPU outside guest topology at row " NR);
  if (migrations != 0 || state_errors != 0 || harness_errors != 0) fail(11, "harness observation failed at row " NR);
  if (control_irq !~ /^(0|1)$/ || treatment_irq !~ /^(0|1)$/) fail(12, "IRQ state is not boolean at row " NR);
  if (family == "irq_dispatch" && (control_irq != 1 || treatment_irq != 1 || control_preempt == 0 || treatment_preempt == 0))
    fail(13, "hard IRQ execution state is not proven at row " NR);
  stats("control"); stats("treatment"); stats("additional"); stats("async");

  p99=value["additional_p99"]+0; p999=value["additional_p999"]+0; maximum=value["additional_max"]+0;
  if (family == "offline") local_reject=(p99>25000 || p999>40000 || maximum>50000 || maximum>=700000);
  else local_reject=(p99>5000 || p999>25000 || maximum>50000 || maximum>=700000);
  recomputed_local=local_reject ? "reject" : "pass";
  if (value["local_gate"] != recomputed_local) fail(14, "local gate mismatch at row " NR);
  asynchronous=(family == "current_stop" || family == "offline");
  if (!asynchronous) {
    if (value["async_gate"] != "na") fail(15, "unexpected asynchronous gate at row " NR);
    for (i=1;i<=ns;i++) if ((value["async_" suffixes[i]]+0) != 0) fail(16, "unexpected asynchronous sample at row " NR);
    async_reject=0; recomputed_async="na";
  } else {
    if ((value["async_min"]+0) == 0) fail(17, "missing asynchronous observation at row " NR);
    async_reject=((value["async_p99"]+0)>10000000 || (value["async_max"]+0)>100000000);
    recomputed_async=async_reject ? "reject" : "pass";
    if (value["async_gate"] != recomputed_async) fail(18, "asynchronous gate mismatch at row " NR);
  }
  rejected=(local_reject || async_reject) ? "reject" : "pass";
  family_count[family]++;
  if (rejected == "reject") rejected_count[family]++;
  print family,cell,samples,warmups,operations,measurement_cpu,migrations,control_irq,treatment_irq,control_preempt,treatment_preempt,state_errors,harness_errors,value["control_min"],value["control_p50"],value["control_p95"],value["control_p99"],value["control_p999"],value["control_max"],value["treatment_min"],value["treatment_p50"],value["treatment_p95"],value["treatment_p99"],value["treatment_p999"],value["treatment_max"],value["additional_min"],value["additional_p50"],value["additional_p95"],value["additional_p99"],value["additional_p999"],value["additional_max"],value["async_min"],value["async_p50"],value["async_p95"],value["async_p99"],value["async_p999"],value["async_max"],value["local_gate"],value["async_gate"],recomputed_local,recomputed_async,rejected;
}
END {
  if (parser_status) exit parser_status;
  if (NR != 682 || family_count["publication"] != 288 || family_count["picker_kick"] != 144 || family_count["irq_dispatch"] != 9 || family_count["recovery"] != 144 || family_count["notifier"] != 48 || family_count["current_stop"] != 24 || family_count["offline"] != 25)
    exit 23;
}
' "$ROWS" > "$TABLE" || die 'malformed, incomplete, or self-inconsistent R4-E4 result rows'

{
	for active in 0 1 2; do for occupancy in 1 8 32 64; do for inner in 0 1 64 4096; do for burst in 1 64 4096; do for owner in clear owned_restart; do
		printf 'publication:%s:%s:%s:%s:%s\n' "$active" "$occupancy" "$inner" "$burst" "$owner"
	done; done; done; done; done
	for occupancy in 1 8 32 64; do for inner in 0 1 64 4096; do for burst in 1 64 4096; do for owner in idle dirty_irq_pending work_running; do
		printf 'picker_kick:%s:%s:%s:%s\n' "$occupancy" "$inner" "$burst" "$owner"
	done; done; done; done
	for outcome in queued false_pending false_running; do for depth in 0 1 64; do printf 'irq_dispatch:%s:%s\n' "$outcome" "$depth"; done; done
	for depth in 1 8 32 64; do for occupancy in 1 8 32 64; do for class in queued delayed current; do for outcome in settle republished_race blocked; do
		printf 'recovery:%s:%s:%s:%s\n' "$depth" "$occupancy" "$class" "$outcome"
	done; done; done; done
	for active in 1 2; do for cursor in first last end_of_pass; do for membership in stable changed_restart; do for class in queued current; do for owner in idle coalesced; do
		printf 'notifier:%s:%s:%s:%s:%s\n' "$active" "$cursor" "$membership" "$class" "$owner"
	done; done; done; done; done
	for source in recovery notifier; do for observation in current_changed same_current_revalidated; do for owner in idle coalesced; do for burst in 1 64 4096; do
		printf 'current_stop:%s:%s:%s:%s\n' "$source" "$observation" "$owner" "$burst"
	done; done; done; done
	for occupancy in 0 1 8 32 64; do for callback in idle irq_pending work_pending work_running self_requeue; do
		printf 'offline:%s:%s\n' "$occupancy" "$callback"
	done; done
} | sort > "$EXPECTED"
tail -n +2 "$TABLE" | cut -f2 | sort > "$ACTUAL"
cmp "$EXPECTED" "$ACTUAL" >/dev/null || die 'missing, duplicate, or unexpected R4-E4 cell'

[ "$(wc -l < "$SUMMARIES" | tr -d ' ')" = 7 ] || die 'R4-E4 summary row count is not exactly 7'
awk '
function fail(code, message) { print "summary-parser: " message > "/dev/stderr"; exit code }
BEGIN { OFS="\t" }
{
  if ($1 != "R4_E4_SUMMARY") fail(2,"bad summary marker");
  delete value; delete seen;
  for (i=2;i<=NF;i++) {
    at=index($i,"="); if (!at) fail(3,"token without equals");
    key=substr($i,1,at-1); val=substr($i,at+1);
    if (key=="" || val=="" || seen[key]++) fail(4,"empty or duplicate key");
    if (key !~ /^(family|rows|rejected_cells|harness_errors|logical_final_bound|availability_only)$/) fail(5,"unknown key");
    value[key]=val;
  }
  family=value["family"];
  if (family !~ /^(publication|picker_kick|irq_dispatch|recovery|notifier|current_stop|offline)$/ || family_seen[family]++) fail(6,"invalid or duplicate family");
  if (value["rows"] !~ /^[0-9]+$/ || value["rejected_cells"] !~ /^[0-9]+$/ || value["harness_errors"] != "0") fail(7,"invalid counts");
  expected=(family=="publication"?288:family=="picker_kick"?144:family=="irq_dispatch"?9:family=="recovery"?144:family=="notifier"?48:family=="current_stop"?24:25);
  if ((value["rows"]+0) != expected) fail(8,"row count changed");
  if (family=="notifier" && value["logical_final_bound"] != "2*A") fail(9,"notifier logical bound missing");
  if ((family=="current_stop" || family=="offline") && value["availability_only"] != "1") fail(10,"availability boundary missing");
  if (family!="notifier" && ("logical_final_bound" in value)) fail(11,"unexpected logical bound");
  if (family!="current_stop" && family!="offline" && ("availability_only" in value)) fail(12,"unexpected availability marker");
  print family,value["rows"],value["rejected_cells"],value["harness_errors"];
}
END { if (NR != 7) exit 13 }
' "$SUMMARIES" | sort > "$SUMMARY_TABLE" || die 'malformed R4-E4 summary rows'

awk -F '\t' '
NR==1 { for(i=1;i<=NF;i++) h[$i]=i; next }
{ rows[$h["family"]]++; if ($h["rejected"]=="reject") rejected[$h["family"]]++ }
END { for (family in rows) print family "\t" rows[family] "\t" rejected[family]+0 "\t0" }
' "$TABLE" | sort > "$DERIVED_SUMMARY"
cmp "$SUMMARY_TABLE" "$DERIVED_SUMMARY" >/dev/null || die 'summary rows disagree with independently recomputed rows'

printf 'family\tkey\treason\tobserved_ns\tlimit_ns\n' > "$FAILURES"
awk -F '\t' 'BEGIN{OFS="\t"}
NR==1 {for(i=1;i<=NF;i++) h[$i]=i; next}
{
  family=$h["family"]; key=$h["key"];
  p99=$h["additional_p99"]+0; p999=$h["additional_p999"]+0; maximum=$h["additional_max"]+0;
  p99_limit=(family=="offline"?25000:5000); p999_limit=(family=="offline"?40000:25000);
  if (p99>p99_limit) print family,key,"additional_p99",p99,p99_limit;
  if (p999>p999_limit) print family,key,"additional_p999",p999,p999_limit;
  if (maximum>50000) print family,key,"additional_max",maximum,50000;
  if (maximum>=700000) print family,key,"additional_reached_base_slice",maximum,699999;
  if (family=="current_stop" || family=="offline") {
    async_p99=$h["async_p99"]+0; async_max=$h["async_max"]+0;
    if (async_p99>10000000) print family,key,"async_p99",async_p99,10000000;
    if (async_max>100000000) print family,key,"async_max",async_max,100000000;
  }
}' "$TABLE" >> "$FAILURES"

rejected_cells=$(awk -F '\t' 'NR==1{for(i=1;i<=NF;i++)h[$i]=i;next} $h["rejected"]=="reject"{n++} END{print n+0}' "$TABLE")
threshold_breaches=$(($(wc -l < "$FAILURES") - 1))
tail -n +2 "$FAILURES" | jq -Rn '[inputs | split("\t") | {family:.[0],key:.[1],reason:.[2],observed_ns:(.[3]|tonumber),limit_ns:(.[4]|tonumber)}]' > "$OUT/threshold-failures.json"
jq -n --argjson rejected "$rejected_cells" --argjson breaches "$threshold_breaches" '
{
  schema_version:1,
  id:"sched-exec-lease-p5a-r4-e4-measurement-parser-result-v1",
  status:"passed_exact_682_cell_parser",
  result_rows:682,
  family_rows:{publication:288,picker_kick:144,irq_dispatch:9,recovery:144,notifier:48,current_stop:24,offline:25},
  measured_pairs:6820000,
  rejected_cells:$rejected,
  threshold_breaches:$breaches,
  malformed_or_missing_rows:0,
  duplicate_or_unexpected_cells:0,
  harness_observation_failures:0,
  summary_mismatches:0
}' > "$OUT/result.json"

printf 'rows=682\nrejected_cells=%s\nthreshold_breaches=%s\n' "$rejected_cells" "$threshold_breaches"
