#!/usr/bin/env bash
set -euo pipefail

ROOT="${CAPSCHED_WORKSPACE:-/media/nia/scsiusb/dev/linux-cap}"
LINUX="$ROOT/linux"
OUT_ROOT="${CAPSCHED_MNIC_HT_OBS_OUT_ROOT:-$ROOT/build/modern-nic-hypertag-observation-ledger}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
RUN_DIR="$OUT_ROOT/$STAMP"
LEDGER="$RUN_DIR/observation-ledger.tsv"
TRACEFS_PLAN="$RUN_DIR/tracefs-plan.txt"
GAPS="$RUN_DIR/semantic-gaps.tsv"
SUMMARY="$RUN_DIR/summary.txt"
SEED="$ROOT/capsched/capsched-models/analysis/modern-nic-hypertag-observation-ledger-v1.json"

mkdir -p "$RUN_DIR"

require()
{
	if ! command -v "$1" >/dev/null 2>&1; then
		echo "error: missing required command: $1" >&2
		exit 1
	fi
}

first_grep_fixed()
{
	local pattern="$1"
	local file="$2"

	git -C "$LINUX" grep -n -F "$pattern" -- "$file" | head -n 1 || true
}

split_match()
{
	awk -F: '{
		code = substr($0, length($1) + length($2) + 3);
		gsub(/\t/, " ", code);
		print $1 "\t" $2 "\t" code;
	}'
}

write_headers()
{
	printf 'receipt_or_carrier\trow_kind\tsemantic_role\tsource_file\tline\tavailable\tsymbol_or_pattern\tconfidence\tobservation_surface\tstub_shape\tforbidden_shortcut\tobservation_only\tauthority_claim\tmonitor_verified\tbehavior_change\tprotection_claim\tcode\n' > "$LEDGER"
	printf 'gap_id\treceipt_or_carrier\tseverity\tevidence\trequired_next_step\n' > "$GAPS"
}

append_gap()
{
	local gap_id="$1"
	local receipt="$2"
	local severity="$3"
	local evidence="$4"
	local next_step="$5"

	printf '%s\t%s\t%s\t%s\t%s\n' \
		"$gap_id" "$receipt" "$severity" "$evidence" "$next_step" >> "$GAPS"
}

append_external_gap()
{
	local receipt="$1"
	local semantic_role="$2"
	local observation_surface="$3"
	local stub_shape="$4"
	local forbidden_shortcut="$5"
	local gap_id="$6"
	local next_step="$7"

	printf '%s\t%s\t%s\t%s\t\tno\tnot_in_linux\tnot_in_linux\t%s\t%s\t%s\ttrue\tfalse\tfalse\tfalse\tfalse\t\n' \
		"$receipt" "external_gap" "$semantic_role" "not_in_linux" \
		"$observation_surface" "$stub_shape" "$forbidden_shortcut" >> "$LEDGER"
	append_gap "$gap_id" "$receipt" high \
		"required root is outside upstream Linux source" "$next_step"
}

append_anchor()
{
	local receipt="$1"
	local row_kind="$2"
	local semantic_role="$3"
	local file="$4"
	local pattern="$5"
	local symbol="$6"
	local confidence="$7"
	local observation_surface="$8"
	local stub_shape="$9"
	local forbidden_shortcut="${10}"
	local gap_id="${11}"
	local next_step="${12}"
	local match

	match="$(first_grep_fixed "$pattern" "$file")"
	if [ -n "$match" ]; then
		split_match <<< "$match" |
			awk -F '\t' -v receipt="$receipt" -v row_kind="$row_kind" \
				-v semantic_role="$semantic_role" -v symbol="$symbol" \
				-v confidence="$confidence" -v observation_surface="$observation_surface" \
				-v stub_shape="$stub_shape" -v forbidden_shortcut="$forbidden_shortcut" \
				'{ print receipt "\t" row_kind "\t" semantic_role "\t" $1 "\t" $2 "\tyes\t" symbol "\t" confidence "\t" observation_surface "\t" stub_shape "\t" forbidden_shortcut "\ttrue\tfalse\tfalse\tfalse\tfalse\t" $3 }' \
				>> "$LEDGER"
	else
		printf '%s\t%s\t%s\t%s\t\tno\t%s\tmissing\t%s\t%s\t%s\ttrue\tfalse\tfalse\tfalse\tfalse\t\n' \
			"$receipt" "$row_kind" "$semantic_role" "$file" "$symbol" \
			"$observation_surface" "$stub_shape" "$forbidden_shortcut" >> "$LEDGER"
		append_gap "$gap_id" "$receipt" medium \
			"missing source anchor: $file:$symbol" "$next_step"
	fi
}

write_ledger()
{
	write_headers

	append_external_gap LocalDomainDeviceLease local_monitor_compilation \
		"root-management admission and cluster lease compilation" \
		"opaque local lease id with no direct queue/DMA/IRQ authority" \
		"signed cluster lease text or scheduler placement is not local monitor authority" \
		HTOBS-GAP-001 \
		"define external root-management and local monitor compilation observation before any distributed lease claim"

	append_anchor DeviceRootReceipt source_anchor pci_driver_binding \
		drivers/net/ethernet/intel/ice/ice_main.c ".probe = ice_probe," \
		"ice_driver.probe" source_observed \
		"PCI driver binding visibility" \
		"DeviceRootReceipt placeholder without IOMMU/MSI/queue side effects" \
		"PCI driver binding is not DeviceRootReceipt" \
		HTOBS-GAP-010 \
		"map future monitor device-root registration call"
	append_anchor DeviceRootReceipt source_anchor pci_driver_registration \
		drivers/net/ethernet/intel/ice/ice_main.c "pci_register_driver(&ice_driver);" \
		"pci_register_driver" source_observed \
		"PCI registration visibility" \
		"DeviceRootReceipt placeholder without IOMMU/MSI/queue side effects" \
		"PCI registration is not DeviceRootReceipt" \
		HTOBS-GAP-011 \
		"map future monitor device-root registration call"
	append_anchor DeviceRootReceipt source_anchor devlink_registration \
		drivers/net/ethernet/intel/ice/devlink/devlink.c "void ice_devlink_register(struct ice_pf *pf)" \
		"ice_devlink_register" source_observed \
		"devlink registration visibility" \
		"DeviceRootReceipt placeholder without devlink authority" \
		"devlink registration is not DeviceRootReceipt" \
		HTOBS-GAP-012 \
		"keep devlink policy separate from monitor receipt minting"
	append_anchor DeviceRootReceipt trace_surface iommu_attach_tracepoint \
		include/trace/events/iommu.h "DEFINE_EVENT(iommu_device_event, attach_device_to_domain," \
		"iommu:attach_device_to_domain" source_observed \
		"IOMMU attach tracepoint visibility" \
		"DeviceRootReceipt placeholder without IOMMU authority" \
		"IOMMU attach trace visibility is not DeviceRootReceipt" \
		HTOBS-GAP-013 \
		"map future monitor-owned device DMA root receipt"

	append_anchor VfEpochReceipt source_anchor vf_lookup \
		drivers/net/ethernet/intel/ice/ice_vf_lib.c "struct ice_vf *ice_get_vf_by_id(struct ice_pf *pf, u16 vf_id)" \
		"ice_get_vf_by_id" source_observed \
		"VF id lookup visibility" \
		"VfEpochReceipt placeholder without mailbox or queue authority" \
		"vf_id lookup is not VF epoch authority" \
		HTOBS-GAP-020 \
		"define monitor VF epoch mint and stale-id rejection"
	append_anchor VfEpochReceipt source_anchor vf_reset \
		drivers/net/ethernet/intel/ice/ice_vf_lib.c "int ice_reset_vf(struct ice_vf *vf, u32 flags)" \
		"ice_reset_vf" source_observed \
		"VF reset path visibility" \
		"VfEpochReceipt placeholder without reset side effects" \
		"reset completion is not fresh VF epoch authority" \
		HTOBS-GAP-021 \
		"define monitor VF epoch bump after DMA/IRQ/queue revoke receipts"
	append_anchor VfEpochReceipt source_anchor vf_active_state \
		drivers/net/ethernet/intel/ice/ice_vf_lib.h "ICE_VF_STATE_ACTIVE," \
		"ICE_VF_STATE_ACTIVE" source_observed \
		"VF active state visibility" \
		"VfEpochReceipt placeholder without state-bit authority" \
		"VF ACTIVE state is not VF epoch authority" \
		HTOBS-GAP-022 \
		"keep Linux state bits outside monitor authority"
	append_anchor VfEpochReceipt source_anchor vf_disabled_state \
		drivers/net/ethernet/intel/ice/ice_vf_lib.h "ICE_VF_STATE_DIS," \
		"ICE_VF_STATE_DIS" source_observed \
		"VF disabled state visibility" \
		"VfEpochReceipt placeholder without state-bit authority" \
		"VF DIS state is not VF epoch authority" \
		HTOBS-GAP-023 \
		"keep Linux state bits outside monitor authority"

	append_anchor QueueLeaseReceipt source_anchor vsi_object \
		drivers/net/ethernet/intel/ice/ice.h "struct ice_vsi {" \
		"struct ice_vsi" source_observed \
		"VSI lifecycle visibility" \
		"QueueLeaseReceipt placeholder without queue mutation" \
		"VSI reachability is not QueueLeaseReceipt" \
		HTOBS-GAP-030 \
		"define monitor QueueTag and queue epoch root"
	append_anchor QueueLeaseReceipt source_anchor q_vector_object \
		drivers/net/ethernet/intel/ice/ice.h "struct ice_q_vector {" \
		"struct ice_q_vector" source_observed \
		"q_vector/NAPI/IRQ grouping visibility" \
		"QueueLeaseReceipt placeholder without IRQ/DMA authority" \
		"q_vector reachability is not QueueLeaseReceipt" \
		HTOBS-GAP-031 \
		"define QueueLease to q_vector mapping without treating q_vector as authority"
	append_anchor QueueLeaseReceipt source_anchor napi_binding \
		drivers/net/ethernet/intel/ice/ice_base.c "netif_napi_add_config(vsi->netdev, &q_vector->napi," \
		"netif_napi_add_config" source_observed \
		"NAPI binding visibility" \
		"QueueLeaseReceipt placeholder without NAPI authority" \
		"NAPI binding is not QueueLeaseReceipt" \
		HTOBS-GAP-032 \
		"map future queue ledger to NAPI only as observation"
	append_anchor QueueLeaseReceipt source_anchor vf_queue_config \
		drivers/net/ethernet/intel/ice/virt/queues.c "int ice_vc_cfg_qs_msg(struct ice_vf *vf, u8 *msg)" \
		"ice_vc_cfg_qs_msg" source_observed \
		"VF queue config handler visibility" \
		"QueueLeaseReceipt placeholder without queue enable" \
		"VF queue config handler is not QueueLeaseReceipt" \
		HTOBS-GAP-033 \
		"map VF queue config carrier to future monitor QueueLease receipt"
	append_anchor QueueLeaseReceipt source_anchor queue_pair_disable \
		drivers/net/ethernet/intel/ice/ice_base.c "int ice_qp_dis(struct ice_vsi *vsi, u16 q_idx)" \
		"ice_qp_dis" source_observed \
		"queue disable visibility" \
		"QueueLeaseReceipt placeholder without revoke authority" \
		"queue disable is not QueueLease revoke" \
		HTOBS-GAP-034 \
		"map future QueueRevokeReceipt consumption"

	append_anchor DmaMemoryViewReceipt source_anchor vf_tx_dma_ring_addr \
		drivers/net/ethernet/intel/ice/virt/queues.c "vsi->tx_rings[q_idx]->dma = qpi->txq.dma_ring_addr;" \
		"VF tx dma_ring_addr copy" source_observed \
		"VF-provided Tx DMA address visibility" \
		"DmaMemoryViewReceipt placeholder without dma_map/iommu side effects" \
		"VF-provided DMA address is not MemoryView authority" \
		HTOBS-GAP-040 \
		"define DMA address carrier requiring MemoryView receipt"
	append_anchor DmaMemoryViewReceipt source_anchor vf_rx_dma_ring_addr \
		drivers/net/ethernet/intel/ice/virt/queues.c "ring->dma = qpi->rxq.dma_ring_addr;" \
		"VF rx dma_ring_addr copy" source_observed \
		"VF-provided Rx DMA address visibility" \
		"DmaMemoryViewReceipt placeholder without dma_map/iommu side effects" \
		"VF-provided DMA address is not MemoryView authority" \
		HTOBS-GAP-041 \
		"define DMA address carrier requiring MemoryView receipt"
	append_anchor DmaMemoryViewReceipt source_anchor tx_context_program \
		drivers/net/ethernet/intel/ice/ice_base.c "ice_setup_tx_ctx(struct ice_tx_ring *ring, struct ice_tlan_ctx *tlan_ctx, u16 pf_q)" \
		"ice_setup_tx_ctx" source_observed \
		"Tx hardware context programming visibility" \
		"DmaMemoryViewReceipt placeholder without queue context write" \
		"hardware context programming is not MemoryView receipt" \
		HTOBS-GAP-042 \
		"map future DmaMemoryViewReceipt before context programming"
	append_anchor DmaMemoryViewReceipt source_anchor rx_context_program \
		drivers/net/ethernet/intel/ice/ice_base.c "static int ice_setup_rx_ctx(struct ice_rx_ring *ring)" \
		"ice_setup_rx_ctx" source_observed \
		"Rx hardware context programming visibility" \
		"DmaMemoryViewReceipt placeholder without queue context write" \
		"hardware context programming is not MemoryView receipt" \
		HTOBS-GAP-043 \
		"map future DmaMemoryViewReceipt before context programming"
	append_anchor DmaMemoryViewReceipt trace_surface dma_map_trace \
		include/trace/events/dma.h "DEFINE_EVENT(dma_map, name, \\" \
		"dma_map trace family" source_observed \
		"DMA map trace visibility" \
		"DmaMemoryViewReceipt placeholder without DMA authority" \
		"DMA trace visibility is not MemoryView receipt" \
		HTOBS-GAP-044 \
		"map future monitor DMA receipt separately from Linux DMA API"
	append_anchor DmaMemoryViewReceipt trace_surface iommu_unmap_trace \
		include/trace/events/iommu.h "TRACE_EVENT(unmap," \
		"iommu:unmap" source_observed \
		"IOMMU unmap trace visibility" \
		"DmaMemoryViewReceipt placeholder without IOTLB completion authority" \
		"IOMMU unmap trace visibility is not MemoryView receipt" \
		HTOBS-GAP-045 \
		"map future monitor IOTLB completion and DMA drain receipt"

	append_anchor IrqRouteReceipt source_anchor vf_irq_map \
		drivers/net/ethernet/intel/ice/virt/queues.c "int ice_vc_cfg_irq_map_msg(struct ice_vf *vf, u8 *msg)" \
		"ice_vc_cfg_irq_map_msg" source_observed \
		"VF IRQ map handler visibility" \
		"IrqRouteReceipt placeholder without IRQ programming" \
		"VF IRQ map handler is not IrqRouteReceipt" \
		HTOBS-GAP-050 \
		"map future monitor IRQ route receipt"
	append_anchor IrqRouteReceipt trace_surface irq_entry_trace \
		include/trace/events/irq.h "TRACE_EVENT(irq_handler_entry," \
		"irq:irq_handler_entry" source_observed \
		"IRQ handler entry visibility" \
		"IrqRouteReceipt placeholder without IRQ authority" \
		"IRQ handler trace is not IrqRouteReceipt" \
		HTOBS-GAP-051 \
		"map future monitor IRQ route validation"
	append_anchor IrqRouteReceipt trace_surface irq_exit_trace \
		include/trace/events/irq.h "TRACE_EVENT(irq_handler_exit," \
		"irq:irq_handler_exit" source_observed \
		"IRQ handler exit visibility" \
		"IrqRouteReceipt placeholder without IRQ authority" \
		"IRQ handler trace is not IrqRouteReceipt" \
		HTOBS-GAP-052 \
		"map future monitor IRQ route invalidation"

	append_anchor LedgerRootReceipt source_anchor next_to_watch_publish \
		drivers/net/ethernet/intel/ice/ice_txrx.c "first->next_to_watch = tx_desc;" \
		"next_to_watch publish" source_observed \
		"TX completion sentinel visibility" \
		"LedgerRootReceipt placeholder without descriptor write" \
		"next_to_watch is not DescriptorLedger authority" \
		HTOBS-GAP-060 \
		"map future DescriptorLedger publication event"
	append_anchor LedgerRootReceipt source_anchor tail_doorbell \
		drivers/net/ethernet/intel/ice/ice_txrx.c "writel_relaxed(i, tx_ring->tail);" \
		"TX tail doorbell" source_observed \
		"tail doorbell visibility" \
		"LedgerRootReceipt placeholder without doorbell side effect" \
		"tail doorbell visibility is not ledger authority" \
		HTOBS-GAP-061 \
		"map future ledger to doorbell correlation"
	append_anchor LedgerRootReceipt trace_surface clean_tx_trace \
		drivers/net/ethernet/intel/ice/ice_trace.h "DEFINE_TX_TEMPLATE_OP_EVENT(ice_clean_tx_irq);" \
		"ice_clean_tx_irq trace" source_observed \
		"TX completion trace visibility" \
		"CompletionEndpoint placeholder without completion authority" \
		"completion trace is not CompletionSettlement authority" \
		HTOBS-GAP-062 \
		"map future CompletionSettlement id"
	append_anchor LedgerRootReceipt trace_surface clean_rx_trace \
		drivers/net/ethernet/intel/ice/ice_trace.h "DEFINE_EVENT(ice_rx_template, ice_clean_rx_irq," \
		"ice_clean_rx_irq trace" source_observed \
		"RX completion trace visibility" \
		"CompletionEndpoint placeholder without delivery authority" \
		"RX trace is not endpoint authority" \
		HTOBS-GAP-063 \
		"map future RX delivery settlement id"

	append_anchor TypedEndpointCarriers source_anchor vf_mailbox_dispatch \
		drivers/net/ethernet/intel/ice/virt/virtchnl.c "void ice_vc_process_vf_msg(struct ice_pf *pf, struct ice_rq_event_info *event," \
		"ice_vc_process_vf_msg" source_observed \
		"VF mailbox dispatch visibility" \
		"VFMailboxEndpoint carrier placeholder without message effects" \
		"virtchnl dispatch is not endpoint authority" \
		HTOBS-GAP-070 \
		"map future VFMailboxEndpoint carrier"
	append_anchor TypedEndpointCarriers source_anchor vf_queue_budget \
		drivers/net/ethernet/intel/ice/virt/queues.c "int ice_vc_cfg_q_bw(struct ice_vf *vf, u8 *msg)" \
		"ice_vc_cfg_q_bw" source_observed \
		"VF queue bandwidth handler visibility" \
		"QueueBudgetEndpoint placeholder without rate change" \
		"queue bandwidth handler is not budget authority" \
		HTOBS-GAP-071 \
		"map future QueueBudgetEndpoint carrier"
	append_anchor TypedEndpointCarriers source_anchor vf_fdir_add \
		drivers/net/ethernet/intel/ice/virt/fdir.c "int ice_vc_add_fdir_fltr(struct ice_vf *vf, u8 *msg)" \
		"ice_vc_add_fdir_fltr" source_observed \
		"VF FDIR offload request visibility" \
		"OffloadEndpoint placeholder without offload effect" \
		"FDIR handler is not OffloadCap authority" \
		HTOBS-GAP-072 \
		"map future OffloadEndpoint carrier and completion generation"
	append_anchor TypedEndpointCarriers source_anchor representor_xmit \
		drivers/net/ethernet/intel/ice/ice_eswitch.c "ice_eswitch_port_start_xmit(struct sk_buff *skb, struct net_device *netdev)" \
		"ice_eswitch_port_start_xmit" source_observed \
		"representor xmit visibility" \
		"RepresentorForwardEndpoint placeholder without xmit effect" \
		"representor xmit is not lower QueueLease authority" \
		HTOBS-GAP-073 \
		"map future RepresentorForwardEndpoint to lower QueueLease"
	append_anchor TypedEndpointCarriers source_anchor tc_flower_offload \
		drivers/net/ethernet/intel/ice/ice_tc_lib.c "int ice_add_cls_flower(struct net_device *netdev, struct ice_vsi *vsi," \
		"ice_add_cls_flower" source_observed \
		"TC flower offload visibility" \
		"OffloadEndpoint placeholder without hardware rule effect" \
		"TC handler is not OffloadCap authority" \
		HTOBS-GAP-074 \
		"map future offload rule generation and stale-rule invalidation"
	append_anchor TypedEndpointCarriers source_anchor service_task \
		drivers/net/ethernet/intel/ice/ice_main.c "static void ice_service_task(struct work_struct *work)" \
		"ice_service_task" source_observed \
		"service worker visibility" \
		"ServiceWorkCarrier placeholder without worker execution effect" \
		"service worker identity is not caller authority" \
		HTOBS-GAP-075 \
		"map future service/caller carrier and BudgetTicket"

	append_anchor RevokeAndHandoffReceipts source_anchor queue_pair_disable \
		drivers/net/ethernet/intel/ice/ice_base.c "int ice_qp_dis(struct ice_vsi *vsi, u16 q_idx)" \
		"ice_qp_dis" source_observed \
		"queue disable visibility" \
		"QueueRevokeReceipt placeholder without queue disable" \
		"queue disable is not revoke safety" \
		HTOBS-GAP-080 \
		"map future QueueRevokeReceipt to DMA/IRQ/ledger settlement"
	append_anchor RevokeAndHandoffReceipts source_anchor vf_reset \
		drivers/net/ethernet/intel/ice/ice_vf_lib.c "int ice_reset_vf(struct ice_vf *vf, u32 flags)" \
		"ice_reset_vf" source_observed \
		"VF reset visibility" \
		"NewVfEpochReceipt placeholder without reset side effects" \
		"VF reset completion is not handoff safety" \
		HTOBS-GAP-081 \
		"map future NewVfEpochReceipt after revoke receipts"
	append_anchor RevokeAndHandoffReceipts source_anchor fdir_ctx_done \
		drivers/net/ethernet/intel/ice/virt/fdir.c "ctx_done = &fdir->ctx_done;" \
		"FDIR ctx_done" source_observed \
		"FDIR async completion context visibility" \
		"Offload revoke placeholder without FDIR side effects" \
		"FDIR ctx_done is not offload/revoke authority" \
		HTOBS-GAP-082 \
		"map future FDIR context generation and stale completion quarantine"
	append_anchor RevokeAndHandoffReceipts source_anchor xsk_free \
		drivers/net/ethernet/intel/ice/ice_xsk.c "xsk_buff_free(tx_buf->xdp);" \
		"xsk_buff_free" source_observed \
		"XSK free visibility" \
		"stale completion quarantine placeholder without packet free" \
		"XSK free is not packet memory settlement" \
		HTOBS-GAP-083 \
		"map future stale completion quarantine and generation reset"
}

write_tracefs_plan()
{
	cat > "$TRACEFS_PLAN" <<'PLAN'
# Modern NIC HyperTag observation-only tracefs plan
#
# This file is a plan, not an executed trace run. Do not treat any event below
# as authority or protection evidence.

events:
  net:net_dev_start_xmit
  net:net_dev_xmit
  napi:napi_poll
  irq:irq_handler_entry
  irq:irq_handler_exit
  iommu:map
  iommu:unmap
  dma:dma_map_sg
  dma:dma_unmap_sg
  workqueue:workqueue_queue_work
  workqueue:workqueue_execute_start

candidate_dynamic_probes_observation_only:
  p:ice_vc_process_vf_msg ice_vc_process_vf_msg
  p:ice_vc_cfg_qs_msg ice_vc_cfg_qs_msg
  p:ice_vc_cfg_irq_map_msg ice_vc_cfg_irq_map_msg
  p:ice_vc_cfg_q_bw ice_vc_cfg_q_bw
  p:ice_vc_add_fdir_fltr ice_vc_add_fdir_fltr
  p:ice_qp_dis ice_qp_dis
  p:ice_reset_vf ice_reset_vf
  p:ice_service_task ice_service_task

required_flags_for_any_result_row:
  observation_only=true
  authority_claim=false
  monitor_verified=false
  behavior_change=false
  protection_claim=false
PLAN
}

write_summary()
{
	local rows available missing gaps violations seed_exists

	rows="$(awk 'NR > 1 { c++ } END { print c + 0 }' "$LEDGER")"
	available="$(awk -F '\t' 'NR > 1 && $6 == "yes" { c++ } END { print c + 0 }' "$LEDGER")"
	missing="$(awk -F '\t' 'NR > 1 && $6 != "yes" { c++ } END { print c + 0 }' "$LEDGER")"
	gaps="$(awk 'NR > 1 { c++ } END { print c + 0 }' "$GAPS")"
	violations="$(awk -F '\t' 'NR > 1 && !($12 == "true" && $13 == "false" && $14 == "false" && $15 == "false" && $16 == "false") { c++ } END { print c + 0 }' "$LEDGER")"
	if [ -f "$SEED" ]; then
		seed_exists=true
	else
		seed_exists=false
	fi

	{
		printf 'run_dir=%s\n' "$RUN_DIR"
		printf 'ledger=%s\n' "$LEDGER"
		printf 'tracefs_plan=%s\n' "$TRACEFS_PLAN"
		printf 'semantic_gaps=%s\n' "$GAPS"
		printf 'seed=%s\n' "$SEED"
		printf 'seed_exists=%s\n' "$seed_exists"
		printf 'ledger_rows=%s\n' "$rows"
		printf 'available_rows=%s\n' "$available"
		printf 'missing_rows=%s\n' "$missing"
		printf 'gap_rows=%s\n' "$gaps"
		printf 'safety_flag_violations=%s\n' "$violations"
		printf 'observation_only=true\n'
		printf 'authority_claim=false\n'
		printf 'monitor_verified=false\n'
		printf 'behavior_change=false\n'
		printf 'protection_claim=false\n'
	} > "$SUMMARY"
}

main()
{
	require git
	require awk
	require date
	require mkdir

	if [ ! -d "$LINUX/.git" ]; then
		echo "error: Linux repository not found at $LINUX" >&2
		exit 1
	fi

	write_ledger
	write_tracefs_plan
	write_summary

	cat "$SUMMARY"
}

main "$@"
