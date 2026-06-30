#!/usr/bin/env bash
set -euo pipefail

ROOT="${CAPSCHED_WORKSPACE:-/media/nia/scsiusb/dev/linux-cap}"
LINUX="$ROOT/linux"
OUT_ROOT="${CAPSCHED_ICE_REVOKE_OUT_ROOT:-$ROOT/build/ice-revoke-readiness}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
RUN_DIR="$OUT_ROOT/$STAMP"
TRACEPOINTS="$RUN_DIR/tracepoint-inventory.tsv"
ANCHORS="$RUN_DIR/source-anchors.tsv"
READINESS="$RUN_DIR/obligation-readiness.tsv"
GAPS="$RUN_DIR/semantic-gaps.tsv"
SUMMARY="$RUN_DIR/summary.txt"

mkdir -p "$RUN_DIR"

require()
{
	if ! command -v "$1" >/dev/null 2>&1; then
		echo "error: missing required command: $1" >&2
		exit 1
	fi
}

say()
{
	printf '[%s] %s\n' "$(date -Is)" "$*"
}

first_grep_fixed()
{
	local pattern="$1"
	local file="$2"

	git -C "$LINUX" grep -n -F "$pattern" -- "$file" | head -n 1 || true
}

first_grep_regex()
{
	local pattern="$1"
	local file="$2"

	git -C "$LINUX" grep -n -E "$pattern" -- "$file" | head -n 1 || true
}

split_match()
{
	awk -F: '{
		code = substr($0, length($1) + length($2) + 3);
		gsub(/\t/, " ", code);
		print $1 "\t" $2 "\t" code;
	}'
}

append_tracepoint_regex()
{
	local system="$1"
	local event="$2"
	local file="$3"
	local pattern="$4"
	local fields="$5"
	local reason="$6"
	local match

	match="$(first_grep_regex "$pattern" "$file")"
	if [ -n "$match" ]; then
		split_match <<< "$match" |
			awk -F '\t' -v sys="$system" -v event="$event" \
				-v fields="$fields" -v reason="$reason" \
				'{ print sys "\t" event "\t" $1 "\t" $2 "\tyes\texisting_tracepoint\t" fields "\t" reason "\t" $3 }' \
				>> "$TRACEPOINTS"
	else
		printf '%s\t%s\t%s\t\tno\tmissing_tracepoint\t%s\t%s\t\n' \
			"$system" "$event" "$file" "$fields" "$reason" >> "$TRACEPOINTS"
	fi
}

append_anchor_fixed()
{
	local obligation="$1"
	local semantic_role="$2"
	local file="$3"
	local pattern="$4"
	local symbol="$5"
	local confidence="$6"
	local reason="$7"
	local match

	match="$(first_grep_fixed "$pattern" "$file")"
	if [ -n "$match" ]; then
		split_match <<< "$match" |
			awk -F '\t' -v obligation="$obligation" \
				-v semantic_role="$semantic_role" -v symbol="$symbol" \
				-v confidence="$confidence" -v reason="$reason" \
				'{ print obligation "\t" semantic_role "\t" $1 "\t" $2 "\t" symbol "\t" confidence "\t" reason "\t" $3 }' \
				>> "$ANCHORS"
	else
		printf '%s\t%s\t%s\t\t%s\tmissing\t%s\t\n' \
			"$obligation" "$semantic_role" "$file" "$symbol" "$reason" >> "$ANCHORS"
	fi
}

append_readiness()
{
	local obligation="$1"
	local formal_invariant="$2"
	local existing_tracepoints="$3"
	local source_anchors="$4"
	local readiness="$5"
	local confidence="$6"
	local semantic_gap="$7"

	printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\ttrue\tfalse\tfalse\n' \
		"$obligation" "$formal_invariant" "$existing_tracepoints" \
		"$source_anchors" "$readiness" "$confidence" "$semantic_gap" \
		>> "$READINESS"
}

append_gap()
{
	local gap_id="$1"
	local obligation="$2"
	local severity="$3"
	local evidence="$4"
	local required_next_step="$5"

	printf '%s\t%s\t%s\t%s\t%s\n' \
		"$gap_id" "$obligation" "$severity" "$evidence" \
		"$required_next_step" >> "$GAPS"
}

write_tracepoints()
{
	printf 'system\tevent\tsource_file\tline\tavailable\tsource_kind\tfields_summary\treason\tcode\n' > "$TRACEPOINTS"

	append_tracepoint_regex net net_dev_xmit_timeout include/trace/events/net.h \
		'TRACE_EVENT\(net_dev_xmit_timeout,' \
		'dev,driver,queue_index,net_cookie' \
		'outer TX timeout visibility; not queue revoke'
	append_tracepoint_regex napi napi_poll include/trace/events/napi.h \
		'TRACE_EVENT\(napi_poll,' \
		'napi,dev_name,work,budget' \
		'NAPI outer visibility; no completion ledger'
	append_tracepoint_regex irq irq_handler_entry include/trace/events/irq.h \
		'TRACE_EVENT\(irq_handler_entry,' \
		'irq,handler' \
		'IRQ entry visibility; no QueueTag'
	append_tracepoint_regex irq irq_handler_exit include/trace/events/irq.h \
		'TRACE_EVENT\(irq_handler_exit,' \
		'irq,ret' \
		'IRQ exit visibility; no QueueTag'
	append_tracepoint_regex iommu unmap include/trace/events/iommu.h \
		'TRACE_EVENT\(unmap,' \
		'iova,size,unmapped_size' \
		'IOMMU unmap visibility; no queue epoch'
	append_tracepoint_regex dma dma_unmap_sg include/trace/events/dma.h \
		'TRACE_EVENT\(dma_unmap_sg,' \
		'device,phys_addrs,dir,attrs' \
		'DMA unmap visibility; no typed ledger'
	append_tracepoint_regex workqueue workqueue_queue_work include/trace/events/workqueue.h \
		'TRACE_EVENT\(workqueue_queue_work,' \
		'work,workqueue,req_cpu,cpu' \
		'service work scheduling visibility; no service carrier'
	append_tracepoint_regex workqueue workqueue_execute_start include/trace/events/workqueue.h \
		'TRACE_EVENT\(workqueue_execute_start,' \
		'work,function' \
		'service work execution visibility; no caller authority'
}

write_anchors()
{
	printf 'obligation\tsemantic_role\tsource_file\tline\tsymbol_or_pattern\tconfidence\treason\tcode\n' > "$ANCHORS"

	append_anchor_fixed REV-ICE-001 block_submit drivers/net/ethernet/intel/ice/ice_main.c \
		'netif_tx_disable(vsi->netdev);' \
		'netif_tx_disable' source_inferred \
		'blocks many netdev submits but is not monitor QueueTag authority'
	append_anchor_fixed REV-ICE-001 block_submit_queue drivers/net/ethernet/intel/ice/ice_base.c \
		'netif_tx_stop_queue(netdev_get_tx_queue(vsi->netdev, q_idx));' \
		'netif_tx_stop_queue' source_inferred \
		'per-queue stop anchor in ice_qp_dis'

	append_anchor_fixed REV-ICE-003 mask_irq drivers/net/ethernet/intel/ice/ice_main.c \
		'static void ice_vsi_dis_irq(struct ice_vsi *vsi)' \
		'ice_vsi_dis_irq' source_inferred \
		'VSI IRQ masking anchor'
	append_anchor_fixed REV-ICE-003 mask_rx_cause drivers/net/ethernet/intel/ice/ice_main.c \
		'val &= ~QINT_RQCTL_CAUSE_ENA_M;' \
		'QINT_RQCTL_CAUSE_ENA clear' source_inferred \
		'RX queue interrupt cause disabled'
	append_anchor_fixed REV-ICE-003 mask_vector drivers/net/ethernet/intel/ice/ice_main.c \
		'wr32(hw, GLINT_DYN_CTL(vsi->q_vectors[i]->reg_idx), 0);' \
		'GLINT_DYN_CTL clear' source_inferred \
		'vector dynamic control cleared'
	append_anchor_fixed REV-ICE-003 sync_irq drivers/net/ethernet/intel/ice/ice_main.c \
		'synchronize_irq(vsi->q_vectors[i]->irq.virq);' \
		'synchronize_irq q_vector' source_inferred \
		'non-VF q_vector IRQ synchronization'
	append_anchor_fixed REV-ICE-003 vf_sync_exception drivers/net/ethernet/intel/ice/ice_main.c \
		'if (vsi->type == ICE_VSI_VF)' \
		'ICE_VSI_VF synchronize_irq exception' source_inferred \
		'host VF path explicitly skips synchronize_irq'

	append_anchor_fixed REV-ICE-004 stop_lan_tx drivers/net/ethernet/intel/ice/ice_main.c \
		'ice_vsi_stop_lan_tx_rings(vsi, ICE_NO_RESET, 0);' \
		'ice_vsi_stop_lan_tx_rings' source_inferred \
		'LAN Tx ring stop anchor'
	append_anchor_fixed REV-ICE-004 stop_xdp_tx drivers/net/ethernet/intel/ice/ice_main.c \
		'ice_vsi_stop_xdp_tx_rings(vsi);' \
		'ice_vsi_stop_xdp_tx_rings' source_inferred \
		'XDP Tx ring stop anchor'
	append_anchor_fixed REV-ICE-004 stop_rx drivers/net/ethernet/intel/ice/ice_main.c \
		'ice_vsi_stop_all_rx_rings(vsi);' \
		'ice_vsi_stop_all_rx_rings' source_inferred \
		'Rx ring stop anchor'
	append_anchor_fixed REV-ICE-004 clean_tx drivers/net/ethernet/intel/ice/ice_txrx.c \
		'void ice_clean_tx_ring(struct ice_tx_ring *tx_ring)' \
		'ice_clean_tx_ring' source_inferred \
		'Tx ring cleanup anchor'
	append_anchor_fixed REV-ICE-004 clean_rx drivers/net/ethernet/intel/ice/ice_txrx.c \
		'void ice_clean_rx_ring(struct ice_rx_ring *rx_ring)' \
		'ice_clean_rx_ring' source_inferred \
		'Rx ring cleanup anchor'
	append_anchor_fixed REV-ICE-004 qp_clean drivers/net/ethernet/intel/ice/ice_base.c \
		'static void ice_qp_clean_rings(struct ice_vsi *vsi, u16 q_idx)' \
		'ice_qp_clean_rings' source_inferred \
		'per-queue clean anchor'

	append_anchor_fixed REV-ICE-005 xsk_dma_unmap drivers/net/ethernet/intel/ice/ice_xsk.c \
		'xsk_pool_dma_unmap(pool, ICE_RX_DMA_ATTR);' \
		'xsk_pool_dma_unmap' source_inferred \
		'AF_XDP pool DMA unmap anchor'
	append_anchor_fixed REV-ICE-005 tx_dma_unmap drivers/net/ethernet/intel/ice/ice_txrx.c \
		'ice_unmap_and_free_tx_buf(tx_ring, &tx_ring->tx_buf[i]);' \
		'ice_unmap_and_free_tx_buf' source_inferred \
		'Tx DMA unmap/free anchor'

	append_anchor_fixed REV-ICE-006 napi_disable drivers/net/ethernet/intel/ice/ice_main.c \
		'napi_disable(&q_vector->napi);' \
		'napi_disable' source_inferred \
		'NAPI completion execution stop anchor'
	append_anchor_fixed REV-ICE-006 xsk_clean_rx drivers/net/ethernet/intel/ice/ice_xsk.c \
		'void ice_xsk_clean_rx_ring(struct ice_rx_ring *rx_ring)' \
		'ice_xsk_clean_rx_ring' source_inferred \
		'XSK Rx cleanup anchor'
	append_anchor_fixed REV-ICE-006 xsk_clean_xdp drivers/net/ethernet/intel/ice/ice_xsk.c \
		'void ice_xsk_clean_xdp_ring(struct ice_tx_ring *xdp_ring)' \
		'ice_xsk_clean_xdp_ring' source_inferred \
		'XSK XDP Tx cleanup anchor'
	append_anchor_fixed REV-ICE-006 xsk_tx_completed drivers/net/ethernet/intel/ice/ice_xsk.c \
		'xsk_tx_completed(xdp_ring->xsk_pool, xsk_frames);' \
		'xsk_tx_completed' source_inferred \
		'cleanup can notify XSK completion; needs revoke-aware settlement'

	append_anchor_fixed REV-ICE-007 reset_subtask drivers/net/ethernet/intel/ice/ice_main.c \
		'static void ice_reset_subtask(struct ice_pf *pf)' \
		'ice_reset_subtask' source_inferred \
		'reset control service anchor'
	append_anchor_fixed REV-ICE-007 prepare_for_reset drivers/net/ethernet/intel/ice/ice_main.c \
		'ice_prepare_for_reset(struct ice_pf *pf, enum ice_reset_req reset_type)' \
		'ice_prepare_for_reset' source_inferred \
		'prepare reset anchor'
	append_anchor_fixed REV-ICE-007 devlink_reinit_down drivers/net/ethernet/intel/ice/devlink/devlink.c \
		'static void ice_devlink_reinit_down(struct ice_pf *pf)' \
		'ice_devlink_reinit_down' source_inferred \
		'devlink QueueControl reload-down anchor'

	append_anchor_fixed REV-ICE-008 representor_xmit drivers/net/ethernet/intel/ice/ice_eswitch.c \
		'ice_eswitch_port_start_xmit(struct sk_buff *skb, struct net_device *netdev)' \
		'ice_eswitch_port_start_xmit' source_inferred \
		'representor lower dev_queue_xmit anchor'
	append_anchor_fixed REV-ICE-008 stop_repr_all drivers/net/ethernet/intel/ice/ice_eswitch.c \
		'void ice_eswitch_stop_all_tx_queues(struct ice_pf *pf)' \
		'ice_eswitch_stop_all_tx_queues' source_inferred \
		'stop all representor queues anchor'
	append_anchor_fixed REV-ICE-008 stop_repr drivers/net/ethernet/intel/ice/ice_repr.c \
		'void ice_repr_stop_tx_queues(struct ice_repr *repr)' \
		'ice_repr_stop_tx_queues' source_inferred \
		'per-representor stop anchor'

	append_anchor_fixed REV-ICE-009 service_schedule drivers/net/ethernet/intel/ice/ice_main.c \
		'void ice_service_task_schedule(struct ice_pf *pf)' \
		'ice_service_task_schedule' source_inferred \
		'coalesced queue_work service scheduling anchor'
	append_anchor_fixed REV-ICE-009 service_stop drivers/net/ethernet/intel/ice/ice_main.c \
		'static int ice_service_task_stop(struct ice_pf *pf)' \
		'ice_service_task_stop' source_inferred \
		'service work cancel anchor'
	append_anchor_fixed REV-ICE-009 service_task drivers/net/ethernet/intel/ice/ice_main.c \
		'static void ice_service_task(struct work_struct *work)' \
		'ice_service_task' source_inferred \
		'service execution anchor'

	append_anchor_fixed REV-ICE-010 qp_enable drivers/net/ethernet/intel/ice/ice_base.c \
		'int ice_qp_ena(struct ice_vsi *vsi, u16 q_idx)' \
		'ice_qp_ena' source_inferred \
		'per-queue enable/reassign-like anchor'
	append_anchor_fixed REV-ICE-010 rebuild drivers/net/ethernet/intel/ice/ice_main.c \
		'static void ice_rebuild(struct ice_pf *pf, enum ice_reset_req reset_type)' \
		'ice_rebuild' source_inferred \
		'PF rebuild after reset anchor'
	append_anchor_fixed REV-ICE-010 devlink_reinit_up drivers/net/ethernet/intel/ice/devlink/devlink.c \
		'static int ice_devlink_reinit_up(struct ice_pf *pf)' \
		'ice_devlink_reinit_up' source_inferred \
		'devlink reload-up anchor'
}

write_readiness()
{
	printf 'obligation\tformal_invariant\texisting_tracepoints\tsource_anchors\treadiness\tconfidence\tsemantic_gap\tobservation_only\tauthority_claim\tmonitor_verified\n' > "$READINESS"

	append_readiness REV-ICE-001 NoSubmitAfterRevoke partial yes partial_gap_recorded source_inferred \
		'netif stop anchors exist but no QueueTag or queue epoch'
	append_readiness REV-ICE-002 NoOldControlAuthorityAfterRevoke none no not_ready_future_capsched missing \
		'no queue epoch root exists in ice source'
	append_readiness REV-ICE-003 NoReassignWithoutIommuAndIrqInvalidation partial yes partial_gap_recorded source_inferred \
		'IRQ mask/sync anchors exist but VF host path skips synchronize_irq and no monitor IRQ owner exists'
	append_readiness REV-ICE-004 NoLedgerClearBeforeDrain partial yes partial_gap_recorded source_inferred \
		'ring stop/clean anchors exist but no typed ledger or DMA drain proof'
	append_readiness REV-ICE-005 NoReassignWithoutIommuAndIrqInvalidation partial yes partial_gap_recorded source_inferred \
		'DMA unmap anchors exist but no monitor MemoryView/IOMMU root'
	append_readiness REV-ICE-006 NoDeliveryAfterRevoke partial yes partial_gap_recorded source_inferred \
		'NAPI/XSK cleanup anchors exist but xsk_tx_completed needs quarantine-aware settlement'
	append_readiness REV-ICE-007 NoControlAfterRevoke partial yes source_only_gap_recorded source_inferred \
		'reset/devlink anchors exist but no QueueControlCap epoch'
	append_readiness REV-ICE-008 NoRepresentorForwardAfterRevoke partial yes partial_gap_recorded source_inferred \
		'representor stop anchors exist but no lower QueueLease revoke proof'
	append_readiness REV-ICE-009 NoServiceWorkAfterRevoke partial yes source_only_gap_recorded source_inferred \
		'service task is coalesced service authority, not per-Domain carrier'
	append_readiness REV-ICE-010 NoReassignBeforeDrainOrQuarantine partial yes partial_gap_recorded source_inferred \
		'enable/rebuild anchors exist but no old/new queue epoch handoff proof'
}

write_gaps()
{
	printf 'gap_id\tobligation\tseverity\tevidence\trequired_next_step\n' > "$GAPS"

	append_gap queue-epoch REV-ICE-002 high \
		'no QueueTag or queue epoch source anchor' \
		'define monitor QueueTag and queue epoch before enforcement'
	append_gap typed-ledger REV-ICE-004 high \
		'ring stop and clean anchors exist but no SubmitLedger/DescriptorLedger id' \
		'design typed ledger observation or scaffolding'
	append_gap iommu-root REV-ICE-005 high \
		'DMA unmap anchors are Linux-owned' \
		'model monitor MemoryView/IOMMU invalidation ordering'
	append_gap vf-irq-sync REV-ICE-003 high \
		'ice_vsi_dis_irq skips synchronize_irq for ICE_VSI_VF from host' \
		'separate VF IRQ ownership and revoke proof'
	append_gap xsk-quarantine REV-ICE-006 high \
		'xsk_tx_completed can occur during cleanup' \
		'distinguish revoke settlement from stale normal completion'
	append_gap representor-lower-lease REV-ICE-008 high \
		'representor stop is not lower QueueLease revoke' \
		'model lower QueueLease revoke and RepresentorForward invalidation'
	append_gap service-carrier REV-ICE-009 high \
		'ICE_SERVICE_SCHED and queue_work coalesce service work' \
		'service work must be service classified or carry typed provenance'
	append_gap epoch-handoff REV-ICE-010 high \
		'ice_qp_ena/rebuild reload without CapSched old/new epoch handoff' \
		'model queue reassignment epoch protocol'
}

write_summary()
{
	local trace_rows trace_missing anchor_rows anchor_missing readiness_rows gap_rows

	trace_rows="$(tail -n +2 "$TRACEPOINTS" | wc -l)"
	trace_missing="$(tail -n +2 "$TRACEPOINTS" | awk -F '\t' '$5 == "no" { n++ } END { print n + 0 }')"
	anchor_rows="$(tail -n +2 "$ANCHORS" | wc -l)"
	anchor_missing="$(tail -n +2 "$ANCHORS" | awk -F '\t' '$6 == "missing" { n++ } END { print n + 0 }')"
	readiness_rows="$(tail -n +2 "$READINESS" | wc -l)"
	gap_rows="$(tail -n +2 "$GAPS" | wc -l)"

	{
		printf 'status=observation_only_ice_revoke_readiness\n'
		printf 'run_dir=%s\n' "$RUN_DIR"
		printf 'tracepoint_rows=%s\n' "$trace_rows"
		printf 'tracepoint_missing_rows=%s\n' "$trace_missing"
		printf 'source_anchor_rows=%s\n' "$anchor_rows"
		printf 'source_anchor_missing_rows=%s\n' "$anchor_missing"
		printf 'obligation_readiness_rows=%s\n' "$readiness_rows"
		printf 'gap_rows=%s\n' "$gap_rows"
		printf 'authority_claim=false\n'
		printf 'monitor_verified=false\n'
		printf 'implementation_approved=false\n'
	} > "$SUMMARY"

	cat "$SUMMARY"
}

main()
{
	require git
	require awk
	require wc

	if [ ! -d "$LINUX/.git" ]; then
		echo "error: Linux git repo not found at $LINUX" >&2
		exit 1
	fi

	say "writing ice revoke readiness into $RUN_DIR"
	write_tracepoints
	write_anchors
	write_readiness
	write_gaps
	write_summary
	say "done"
}

main "$@"
