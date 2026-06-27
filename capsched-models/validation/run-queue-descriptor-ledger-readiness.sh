#!/usr/bin/env bash
set -euo pipefail

ROOT="${CAPSCHED_WORKSPACE:-/media/nia/scsiusb/dev/linux-cap}"
LINUX="$ROOT/linux"
OUT_ROOT="${CAPSCHED_QDL_OUT_ROOT:-$ROOT/build/queue-descriptor-ledger-readiness}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
RUN_DIR="$OUT_ROOT/$STAMP"
TRACEPOINTS="$RUN_DIR/tracepoint-inventory.tsv"
ANCHORS="$RUN_DIR/source-anchors.tsv"
READINESS="$RUN_DIR/event-readiness.tsv"
GAPS="$RUN_DIR/semantic-gaps.tsv"
SUMMARY="$RUN_DIR/summary.txt"
SCHEMA="$ROOT/capsched/capsched-models/analysis/queue-descriptor-ledger-tags-v1.json"

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

append_tracepoint()
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

append_anchor()
{
	local event_kind="$1"
	local semantic_role="$2"
	local file="$3"
	local pattern="$4"
	local symbol="$5"
	local confidence="$6"
	local trace_patch="$7"
	local driver_map="$8"
	local reason="$9"
	local match

	match="$(first_grep_fixed "$pattern" "$file")"
	if [ -n "$match" ]; then
		split_match <<< "$match" |
			awk -F '\t' -v event_kind="$event_kind" \
				-v semantic_role="$semantic_role" -v symbol="$symbol" \
				-v confidence="$confidence" -v trace_patch="$trace_patch" \
				-v driver_map="$driver_map" -v reason="$reason" \
				'{ print event_kind "\t" semantic_role "\t" $1 "\t" $2 "\t" symbol "\t" confidence "\t" trace_patch "\t" driver_map "\t" reason "\t" $3 }' \
				>> "$ANCHORS"
	else
		printf '%s\t%s\t%s\t\t%s\tmissing\t%s\t%s\t%s\t\n' \
			"$event_kind" "$semantic_role" "$file" "$symbol" \
			"$trace_patch" "$driver_map" "$reason" >> "$ANCHORS"
	fi
}

append_readiness()
{
	local event_kind="$1"
	local phase="$2"
	local existing_tracepoints="$3"
	local source_anchors="$4"
	local readiness="$5"
	local confidence="$6"
	local trace_patch="$7"
	local driver_map="$8"
	local semantic_gap="$9"

	printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\ttrue\tfalse\tfalse\n' \
		"$event_kind" "$phase" "$existing_tracepoints" "$source_anchors" \
		"$readiness" "$confidence" "$trace_patch" "$driver_map" \
		"$semantic_gap" >> "$READINESS"
}

append_gap()
{
	local gap_id="$1"
	local event_kind="$2"
	local severity="$3"
	local evidence="$4"
	local required_next_step="$5"

	printf '%s\t%s\t%s\t%s\t%s\n' \
		"$gap_id" "$event_kind" "$severity" "$evidence" "$required_next_step" \
		>> "$GAPS"
}

write_tracepoints()
{
	printf 'system\tevent\tsource_file\tline\tavailable\tsource_kind\tfields_summary\treason\tcode\n' > "$TRACEPOINTS"

	append_tracepoint net net_dev_queue include/trace/events/net.h \
		'DEFINE_EVENT\(net_dev_template, net_dev_queue,' \
		'skbaddr,len,dev,net_cookie' \
		'outer TX queue visibility; no submit ledger id'
	append_tracepoint net net_dev_start_xmit include/trace/events/net.h \
		'TRACE_EVENT\(net_dev_start_xmit,' \
		'skbaddr,queue_mapping,len,gso,net_cookie' \
		'outer xmit visibility; no descriptor identity'
	append_tracepoint net net_dev_xmit include/trace/events/net.h \
		'TRACE_EVENT\(net_dev_xmit,' \
		'skbaddr,len,rc,dev,net_cookie' \
		'driver xmit return visibility; not a doorbell proof'
	append_tracepoint net net_dev_xmit_timeout include/trace/events/net.h \
		'TRACE_EVENT\(net_dev_xmit_timeout,' \
		'dev,driver,queue_index,net_cookie' \
		'timeout signal; not queue ownership'
	append_tracepoint napi napi_poll include/trace/events/napi.h \
		'TRACE_EVENT\(napi_poll,' \
		'napi,dev_name,work,budget' \
		'NAPI outer completion visibility'
	append_tracepoint skb consume_skb include/trace/events/skb.h \
		'TRACE_EVENT\(consume_skb,' \
		'skbaddr,location' \
		'late skb lifetime visibility; not descriptor settlement'
	append_tracepoint skb kfree_skb include/trace/events/skb.h \
		'TRACE_EVENT\(kfree_skb,' \
		'skbaddr,location,reason,rx_sk,protocol' \
		'drop/free visibility; not enough for queue settlement'
	append_tracepoint irq irq_handler_entry include/trace/events/irq.h \
		'TRACE_EVENT\(irq_handler_entry,' \
		'irq,handler' \
		'IRQ outer visibility; queue mapping is driver-specific'
	append_tracepoint irq irq_handler_exit include/trace/events/irq.h \
		'TRACE_EVENT\(irq_handler_exit,' \
		'irq,ret' \
		'IRQ outer visibility; queue mapping is driver-specific'
	append_tracepoint iommu map include/trace/events/iommu.h \
		'TRACE_EVENT\(map,' \
		'iova,paddr,size' \
		'IOMMU map visibility; no submit ledger link'
	append_tracepoint iommu unmap include/trace/events/iommu.h \
		'TRACE_EVENT\(unmap,' \
		'iova,size,unmapped_size' \
		'IOMMU unmap visibility; no submit ledger link'
	append_tracepoint dma dma_map_sg include/trace/events/dma.h \
		'TRACE_EVENT\(dma_map_sg,' \
		'device,dma_addrs,phys_addrs,lengths,dir,attrs' \
		'scatter-gather DMA map visibility; not dma_map_single'
	append_tracepoint dma dma_map_sg_err include/trace/events/dma.h \
		'TRACE_EVENT\(dma_map_sg_err,' \
		'device,phys_addrs,err,dir,attrs' \
		'scatter-gather DMA map error visibility'
	append_tracepoint dma dma_unmap_sg include/trace/events/dma.h \
		'TRACE_EVENT\(dma_unmap_sg,' \
		'device,phys_addrs,dir,attrs' \
		'scatter-gather DMA unmap visibility'
}

write_anchors()
{
	printf 'event_kind\tsemantic_role\tsource_file\tline\tsymbol_or_pattern\tconfidence\trequires_trace_only_patch\trequires_driver_specific_map\treason\tcode\n' > "$ANCHORS"

	append_anchor queue_bind napi_queue_binding drivers/net/ethernet/intel/e1000e/netdev.c \
		'netif_queue_set_napi(netdev, 0, NETDEV_QUEUE_TYPE_RX, &adapter->napi);' \
		'netif_queue_set_napi RX' source_inferred no yes \
		'queue to NAPI binding exists but no QueueLedger id'
	append_anchor queue_bind napi_queue_binding drivers/net/ethernet/intel/e1000e/netdev.c \
		'netif_queue_set_napi(netdev, 0, NETDEV_QUEUE_TYPE_TX, &adapter->napi);' \
		'netif_queue_set_napi TX' source_inferred no yes \
		'queue to NAPI binding exists but no QueueLedger id'
	append_anchor queue_bind irq_request drivers/net/ethernet/intel/e1000e/netdev.c \
		'err = request_irq(adapter->msix_entries[vector].vector,' \
		'request_irq MSI-X' source_inferred no yes \
		'IRQ vectors are requested but queue ownership is driver-specific'

	append_anchor submit_prepare driver_xmit_entry drivers/net/ethernet/intel/e1000e/netdev.c \
		'static netdev_tx_t e1000_xmit_frame(struct sk_buff *skb,' \
		'e1000_xmit_frame' source_inferred yes yes \
		'driver submit entry exists; no SubmitLedger id is allocated'
	append_anchor submit_prepare netdev_op_binding drivers/net/ethernet/intel/e1000e/netdev.c \
		'.ndo_start_xmit		= e1000_xmit_frame,' \
		'ndo_start_xmit binding' source_inferred no yes \
		'netdev op binds submit path'

	append_anchor dma_map driver_dma_map_function drivers/net/ethernet/intel/e1000e/netdev.c \
		'static int e1000_tx_map(struct e1000_ring *tx_ring, struct sk_buff *skb,' \
		'e1000_tx_map' source_inferred yes yes \
		'DMA map loop exists but is not linked to a SubmitLedger tag'
	append_anchor dma_map dma_map_single drivers/net/ethernet/intel/e1000e/netdev.c \
		'buffer_info->dma = dma_map_single(&pdev->dev,' \
		'dma_map_single' source_inferred yes yes \
		'per-fragment DMA map anchor; generic trace does not link submit id'
	append_anchor dma_map skb_frag_dma_map drivers/net/ethernet/intel/e1000e/netdev.c \
		'buffer_info->dma = skb_frag_dma_map(&pdev->dev, frag,' \
		'skb_frag_dma_map' source_inferred yes yes \
		'fragment DMA map anchor; generic trace does not link submit id'

	append_anchor desc_publish descriptor_publish_function drivers/net/ethernet/intel/e1000e/netdev.c \
		'static void e1000_tx_queue(struct e1000_ring *tx_ring, int tx_flags, int count)' \
		'e1000_tx_queue' source_inferred yes yes \
		'descriptor publication has no generic tracepoint'
	append_anchor desc_publish descriptor_dma_address drivers/net/ethernet/intel/e1000e/netdev.c \
		'tx_desc->buffer_addr = cpu_to_le64(buffer_info->dma);' \
		'tx_desc->buffer_addr' source_inferred yes yes \
		'descriptor receives DMA address; no DescriptorLedger id'
	append_anchor desc_publish descriptor_length_flags drivers/net/ethernet/intel/e1000e/netdev.c \
		'tx_desc->lower.data = cpu_to_le32(txd_lower |' \
		'tx_desc->lower.data' source_inferred yes yes \
		'descriptor receives length/flags; no DescriptorLedger id'

	append_anchor doorbell tail_write drivers/net/ethernet/intel/e1000e/netdev.c \
		'writel(tx_ring->next_to_use, tx_ring->tail);' \
		'tail writel' source_inferred yes yes \
		'tail write is driver-specific and not semantically exposed by generic trace'
	append_anchor doorbell tail_write_wa drivers/net/ethernet/intel/e1000e/netdev.c \
		'e1000e_update_tdt_wa(tx_ring,' \
		'e1000e_update_tdt_wa' source_inferred yes yes \
		'workaround path also advances tail'

	append_anchor irq_entry irq_handler_msi drivers/net/ethernet/intel/e1000e/netdev.c \
		'static irqreturn_t e1000_intr_msi(int __always_unused irq, void *data)' \
		'e1000_intr_msi' source_inferred no yes \
		'IRQ handler exists; queue ownership is not encoded in generic IRQ trace'
	append_anchor irq_entry irq_handler_msix_tx drivers/net/ethernet/intel/e1000e/netdev.c \
		'static irqreturn_t e1000_intr_msix_tx(int __always_unused irq, void *data)' \
		'e1000_intr_msix_tx' source_inferred no yes \
		'MSI-X TX handler exists; needs QueueLedger correlation'
	append_anchor irq_entry irq_handler_msix_rx drivers/net/ethernet/intel/e1000e/netdev.c \
		'static irqreturn_t e1000_intr_msix_rx(int __always_unused irq, void *data)' \
		'e1000_intr_msix_rx' source_inferred no yes \
		'MSI-X RX handler exists; needs QueueLedger correlation'

	append_anchor napi_poll napi_poll_function drivers/net/ethernet/intel/e1000e/netdev.c \
		'static int e1000e_poll(struct napi_struct *napi, int budget)' \
		'e1000e_poll' source_inferred no yes \
		'NAPI poll function exists but does not identify submit ledgers'

	append_anchor completion_observed tx_completion_function drivers/net/ethernet/intel/e1000e/netdev.c \
		'static bool e1000_clean_tx_irq(struct e1000_ring *tx_ring)' \
		'e1000_clean_tx_irq' source_inferred yes yes \
		'TX completion loop exists but has no DescriptorLedger correlation'
	append_anchor completion_observed completion_done_bit drivers/net/ethernet/intel/e1000e/netdev.c \
		'E1000_TXD_STAT_DD' \
		'E1000_TXD_STAT_DD' source_inferred yes yes \
		'descriptor done bit observed by driver, not generic trace'

	append_anchor settle txbuf_unmap drivers/net/ethernet/intel/e1000e/netdev.c \
		'static void e1000_put_txbuf(struct e1000_ring *tx_ring,' \
		'e1000_put_txbuf' source_inferred yes yes \
		'DMA unmap and skb cleanup settlement helper'
	append_anchor settle netdev_completed_queue drivers/net/ethernet/intel/e1000e/netdev.c \
		'netdev_completed_queue(netdev, pkts_compl, bytes_compl);' \
		'netdev_completed_queue' source_inferred yes yes \
		'BQL/netdev settlement exists but no SubmitLedger id'
	append_anchor settle skb_consume drivers/net/ethernet/intel/e1000e/netdev.c \
		'dev_consume_skb_any(skb);' \
		'dev_consume_skb_any' source_inferred yes yes \
		'late skb lifetime settlement is not enough for descriptor proof'

	append_anchor revoke_start device_down_state drivers/net/ethernet/intel/e1000e/netdev.c \
		'test_bit(__E1000_DOWN, &adapter->state)' \
		'__E1000_DOWN state' source_inferred yes yes \
		'driver down/reset state is not a CapSched queue revoke'
	append_anchor revoke_drop tx_ring_clean drivers/net/ethernet/intel/e1000e/netdev.c \
		'static void e1000_clean_tx_ring(struct e1000_ring *tx_ring)' \
		'e1000_clean_tx_ring' source_inferred yes yes \
		'ring cleanup can drop in-flight state but lacks revoke epoch semantics'
	append_anchor revoke_finish tx_ring_reset_indices drivers/net/ethernet/intel/e1000e/netdev.c \
		'tx_ring->next_to_use = 0;' \
		'tx ring index reset' source_inferred yes yes \
		'index reset is not proof that old-epoch queue work is quiesced'
}

write_readiness()
{
	printf 'event_kind\tphase\texisting_tracepoints\tsource_anchors\treadiness\tconfidence\trequires_trace_only_patch\trequires_driver_specific_map\tsemantic_gap\tobservation_only\tauthority_claim\tmonitor_verified\n' > "$READINESS"

	append_readiness queue_bind setup \
		'irq_handler_entry/exit,napi_poll' \
		'netif_queue_set_napi,request_irq' \
		'partially_ready' source_inferred no yes \
		'No QueueLedger/QueueTag id or monitor-owned queue epoch exists in L0.'
	append_readiness submit_prepare submit \
		'net_dev_queue,net_dev_start_xmit,net_dev_xmit' \
		'e1000_xmit_frame,ndo_start_xmit binding' \
		'partially_ready' partially_observed yes yes \
		'Existing tracepoints expose SKB and queue_mapping but not SubmitLedger identity.'
	append_readiness dma_map submit \
		'iommu/map,iommu/unmap,dma_map_sg,dma_map_sg_err,dma_unmap_sg' \
		'e1000_tx_map,dma_map_single,skb_frag_dma_map' \
		'partial_gap_recorded' partially_observed yes yes \
		'Generic DMA/IOMMU traces do not reliably link maps to submit or descriptor ledgers.'
	append_readiness desc_publish submit \
		'none_generic' \
		'e1000_tx_queue,tx_desc field writes' \
		'source_only_gap_recorded' source_inferred yes yes \
		'Descriptor publication has no generic semantic tracepoint.'
	append_readiness doorbell submit \
		'none_generic' \
		'tail writel,e1000e_update_tdt_wa' \
		'source_only_gap_recorded' source_inferred yes yes \
		'Generic writel probes are not semantic queue doorbell events.'
	append_readiness irq_entry completion \
		'irq_handler_entry,irq_handler_exit' \
		'e1000_intr_msi,e1000_intr_msix_tx,e1000_intr_msix_rx,request_irq' \
		'partially_ready' partially_observed no yes \
		'IRQ trace does not carry QueueLedger ownership.'
	append_readiness napi_poll completion \
		'napi_poll' \
		'e1000e_poll' \
		'partially_ready' partially_observed no yes \
		'NAPI poll reports work/budget but not individual submit ledger settlement.'
	append_readiness completion_observed completion \
		'napi_poll,consume_skb,kfree_skb' \
		'e1000_clean_tx_irq,E1000_TXD_STAT_DD' \
		'source_only_gap_recorded' source_inferred yes yes \
		'Generic skb lifetime events are too late to prove descriptor completion settlement.'
	append_readiness settle settlement \
		'consume_skb,kfree_skb,dma_unmap_sg,iommu/unmap' \
		'e1000_put_txbuf,netdev_completed_queue,dev_consume_skb_any' \
		'partial_gap_recorded' partially_observed yes yes \
		'Settlement needs submit-ledger correlation and explicit outcome.'
	append_readiness revoke_start revocation \
		'none_capsched' \
		'driver down/reset source anchors only' \
		'not_ready_future_capsched' source_inferred yes yes \
		'No CapSched queue revoke epoch exists in L0.'
	append_readiness revoke_drop revocation \
		'none_capsched' \
		'e1000_clean_tx_ring source anchor only' \
		'not_ready_future_capsched' source_inferred yes yes \
		'Cleanup/drop has no CapSched revoke/drop/quarantine semantics.'
	append_readiness revoke_finish revocation \
		'none_capsched' \
		'ring index reset source anchor only' \
		'not_ready_future_capsched' source_inferred yes yes \
		'No proof that old-epoch in-flight queue work is quiesced.'
}

write_gaps()
{
	printf 'gap_id\tevent_kind\tseverity\tevidence\trequired_next_step\n' > "$GAPS"

	append_gap submit-ledger-id submit_prepare high \
		'net tracepoints expose skbaddr and queue_mapping but no SubmitLedger id' \
		'add observation-only submit ledger tag or targeted probe correlation before enforcement'
	append_gap dma-submit-correlation dma_map high \
		'dma_map_single/skb_frag_dma_map anchors exist, but generic DMA/IOMMU traces do not tie maps to submit ledgers' \
		'add driver-local observation tag or model an explicit correlation limit'
	append_gap descriptor-publish desc_publish high \
		'e1000_tx_queue writes descriptors, but there is no generic descriptor publish tracepoint' \
		'add trace-only driver/helper hook at descriptor publication if this path becomes validation target'
	append_gap tail-doorbell doorbell high \
		'tail writel exists and may be batched by netdev_xmit_more, but generic register probes are not semantic doorbells' \
		'add trace-only semantic doorbell event near driver tail advance'
	append_gap completion-ledger completion_observed high \
		'e1000_clean_tx_irq observes descriptor done state, but generic skb/free events cannot reconstruct descriptor ledger settlement' \
		'add trace-only completion event or a driver-specific probe decoder'
	append_gap revoke-semantics revoke_start high \
		'driver down/reset cleanup exists, but no CapSched queue revoke epoch or quarantine/drop outcome exists' \
		'defer revoke validation until CapSched queue epoch/revoke design exists'
	append_gap authority-root all high \
		'all observed state is Linux-mutable and monitor_verified=false' \
		'never use readiness output as a protection proof; use it only to place later model/trace hooks'
	append_gap modern-nic-coverage all medium \
		'e1000e is representative but not modern multi-queue/XDP/page-pool/devlink coverage' \
		'perform N-005 on a modern NIC driver after this readiness baseline'
}

write_summary()
{
	local trace_rows anchor_rows readiness_rows gap_rows trace_missing anchor_missing

	trace_rows=$(($(wc -l < "$TRACEPOINTS") - 1))
	anchor_rows=$(($(wc -l < "$ANCHORS") - 1))
	readiness_rows=$(($(wc -l < "$READINESS") - 1))
	gap_rows=$(($(wc -l < "$GAPS") - 1))
	trace_missing=$(awk -F '\t' 'NR > 1 && $5 == "no" { c++ } END { print c + 0 }' "$TRACEPOINTS")
	anchor_missing=$(awk -F '\t' 'NR > 1 && $6 == "missing" { c++ } END { print c + 0 }' "$ANCHORS")

	{
		echo "timestamp_utc=$STAMP"
		echo "linux_commit=$(git -C "$LINUX" rev-parse HEAD)"
		echo "linux_subject=$(git -C "$LINUX" log -1 --format=%s)"
		echo "schema=$SCHEMA"
		echo "tracepoints=$TRACEPOINTS"
		echo "source_anchors=$ANCHORS"
		echo "readiness=$READINESS"
		echo "gaps=$GAPS"
		echo "tracepoint_rows=$trace_rows"
		echo "tracepoint_missing_rows=$trace_missing"
		echo "source_anchor_rows=$anchor_rows"
		echo "source_anchor_missing_rows=$anchor_missing"
		echo "event_readiness_rows=$readiness_rows"
		echo "gap_rows=$gap_rows"
		echo "status=observation_only_static_readiness"
	} > "$SUMMARY"
}

require git
require awk
require head
require jq
require wc

jq empty "$SCHEMA"

say "queue/descriptor ledger readiness check started"
say "run directory: $RUN_DIR"
write_tracepoints
write_anchors
write_readiness
write_gaps
write_summary
say "tracepoints: $TRACEPOINTS"
say "source anchors: $ANCHORS"
say "readiness: $READINESS"
say "gaps: $GAPS"
say "summary: $SUMMARY"
