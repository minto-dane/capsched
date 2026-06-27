#!/usr/bin/env bash
set -euo pipefail

ROOT="${CAPSCHED_WORKSPACE:-/media/nia/scsiusb/dev/linux-cap}"
LINUX="$ROOT/linux"
OUT_ROOT="${CAPSCHED_ICE_READINESS_OUT_ROOT:-$ROOT/build/ice-modern-nic-readiness}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
RUN_DIR="$OUT_ROOT/$STAMP"
TRACEPOINTS="$RUN_DIR/tracepoint-inventory.tsv"
ANCHORS="$RUN_DIR/source-anchors.tsv"
READINESS="$RUN_DIR/class-readiness.tsv"
GAPS="$RUN_DIR/semantic-gaps.tsv"
SUMMARY="$RUN_DIR/summary.txt"
SOURCE_MAP="$ROOT/capsched/capsched-models/analysis/ice-modern-nic-queuelease-source-map-v1.json"

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

append_tracepoint_fixed()
{
	local system="$1"
	local event="$2"
	local file="$3"
	local pattern="$4"
	local fields="$5"
	local reason="$6"
	local match

	match="$(first_grep_fixed "$pattern" "$file")"
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
	local authority_class="$1"
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
			awk -F '\t' -v authority_class="$authority_class" \
				-v semantic_role="$semantic_role" -v symbol="$symbol" \
				-v confidence="$confidence" -v trace_patch="$trace_patch" \
				-v driver_map="$driver_map" -v reason="$reason" \
				'{ print authority_class "\t" semantic_role "\t" $1 "\t" $2 "\t" symbol "\t" confidence "\t" trace_patch "\t" driver_map "\t" reason "\t" $3 }' \
				>> "$ANCHORS"
	else
		printf '%s\t%s\t%s\t\t%s\tmissing\t%s\t%s\t%s\t\n' \
			"$authority_class" "$semantic_role" "$file" "$symbol" \
			"$trace_patch" "$driver_map" "$reason" >> "$ANCHORS"
	fi
}

append_readiness()
{
	local authority_class="$1"
	local phase="$2"
	local existing_tracepoints="$3"
	local source_anchors="$4"
	local readiness="$5"
	local confidence="$6"
	local trace_patch="$7"
	local driver_map="$8"
	local semantic_gap="$9"

	printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\ttrue\tfalse\tfalse\n' \
		"$authority_class" "$phase" "$existing_tracepoints" \
		"$source_anchors" "$readiness" "$confidence" "$trace_patch" \
		"$driver_map" "$semantic_gap" >> "$READINESS"
}

append_gap()
{
	local gap_id="$1"
	local authority_class="$2"
	local severity="$3"
	local evidence="$4"
	local required_next_step="$5"

	printf '%s\t%s\t%s\t%s\t%s\n' \
		"$gap_id" "$authority_class" "$severity" "$evidence" \
		"$required_next_step" >> "$GAPS"
}

write_tracepoints()
{
	printf 'system\tevent\tsource_file\tline\tavailable\tsource_kind\tfields_summary\treason\tcode\n' > "$TRACEPOINTS"

	append_tracepoint_regex net net_dev_start_xmit include/trace/events/net.h \
		'TRACE_EVENT\(net_dev_start_xmit,' \
		'skbaddr,queue_mapping,len,gso,net_cookie' \
		'outer SKB xmit visibility; no SubmitLedger or descriptor identity'
	append_tracepoint_regex net net_dev_xmit include/trace/events/net.h \
		'TRACE_EVENT\(net_dev_xmit,' \
		'skbaddr,len,rc,dev,net_cookie' \
		'driver xmit return visibility; not a doorbell proof'
	append_tracepoint_regex napi napi_poll include/trace/events/napi.h \
		'TRACE_EVENT\(napi_poll,' \
		'napi,dev_name,work,budget' \
		'NAPI outer completion visibility'
	append_tracepoint_regex irq irq_handler_entry include/trace/events/irq.h \
		'TRACE_EVENT\(irq_handler_entry,' \
		'irq,handler' \
		'IRQ outer visibility; q_vector mapping is driver-specific'
	append_tracepoint_regex irq irq_handler_exit include/trace/events/irq.h \
		'TRACE_EVENT\(irq_handler_exit,' \
		'irq,ret' \
		'IRQ outer visibility; q_vector mapping is driver-specific'
	append_tracepoint_regex skb consume_skb include/trace/events/skb.h \
		'TRACE_EVENT\(consume_skb,' \
		'skbaddr,location' \
		'late SKB lifetime visibility; not descriptor settlement'
	append_tracepoint_regex skb kfree_skb include/trace/events/skb.h \
		'TRACE_EVENT\(kfree_skb,' \
		'skbaddr,location,reason,rx_sk,protocol' \
		'drop/free visibility; not QueueLease settlement'
	append_tracepoint_regex iommu map include/trace/events/iommu.h \
		'TRACE_EVENT\(map,' \
		'iova,paddr,size' \
		'IOMMU map visibility; no submit class linkage'
	append_tracepoint_regex iommu unmap include/trace/events/iommu.h \
		'TRACE_EVENT\(unmap,' \
		'iova,size,unmapped_size' \
		'IOMMU unmap visibility; no submit class linkage'
	append_tracepoint_regex dma dma_map_sg include/trace/events/dma.h \
		'TRACE_EVENT\(dma_map_sg,' \
		'device,dma_addrs,phys_addrs,lengths,dir,attrs' \
		'scatter-gather DMA visibility; ice also uses dma_map_single'

	append_tracepoint_fixed ice ice_xmit_frame_ring drivers/net/ethernet/intel/ice/ice_trace.h \
		'DEFINE_XMIT_TEMPLATE_OP_EVENT(ice_xmit_frame_ring);' \
		'ring,skb,devname' \
		'driver SKB xmit trace; no SubmitLedger id'
	append_tracepoint_fixed ice ice_xmit_frame_ring_drop drivers/net/ethernet/intel/ice/ice_trace.h \
		'DEFINE_XMIT_TEMPLATE_OP_EVENT(ice_xmit_frame_ring_drop);' \
		'ring,skb,devname' \
		'driver SKB drop trace; no revoke/drop outcome'
	append_tracepoint_fixed ice ice_clean_tx_irq drivers/net/ethernet/intel/ice/ice_trace.h \
		'DEFINE_TX_TEMPLATE_OP_EVENT(ice_clean_tx_irq);' \
		'ring,desc,buf,devname' \
		'driver TX completion trace; no typed completion ledger'
	append_tracepoint_fixed ice ice_clean_tx_irq_unmap drivers/net/ethernet/intel/ice/ice_trace.h \
		'DEFINE_TX_TEMPLATE_OP_EVENT(ice_clean_tx_irq_unmap);' \
		'ring,desc,buf,devname' \
		'driver TX unmap trace; no typed submit correlation'
	append_tracepoint_fixed ice ice_clean_tx_irq_unmap_eop drivers/net/ethernet/intel/ice/ice_trace.h \
		'DEFINE_TX_TEMPLATE_OP_EVENT(ice_clean_tx_irq_unmap_eop);' \
		'ring,desc,buf,devname' \
		'driver TX EOP trace; no typed submit correlation'
	append_tracepoint_fixed ice ice_clean_rx_irq drivers/net/ethernet/intel/ice/ice_trace.h \
		'DEFINE_EVENT(ice_rx_template, ice_clean_rx_irq,' \
		'ring,desc,devname' \
		'driver RX completion trace; no delivery authority'
	append_tracepoint_fixed ice ice_clean_rx_irq_indicate drivers/net/ethernet/intel/ice/ice_trace.h \
		'DEFINE_EVENT(ice_rx_indicate_template, ice_clean_rx_irq_indicate,' \
		'ring,desc,skb,devname' \
		'driver RX indicate trace; no endpoint authority'
	append_tracepoint_fixed ice ice_eswitch_br_port_link drivers/net/ethernet/intel/ice/ice_trace.h \
		'ice_eswitch_br_port_link,' \
		'vport_num,port_type' \
		'eswitch trace; not representor transmit derivation'
	append_tracepoint_fixed ice ice_eswitch_br_port_unlink drivers/net/ethernet/intel/ice/ice_trace.h \
		'ice_eswitch_br_port_unlink,' \
		'vport_num,port_type' \
		'eswitch trace; not representor transmit derivation'
}

write_anchors()
{
	printf 'authority_class\tsemantic_role\tsource_file\tline\tsymbol_or_pattern\tconfidence\trequires_trace_only_patch\trequires_driver_specific_map\treason\tcode\n' > "$ANCHORS"

	append_anchor_fixed QueueBind vsi_object drivers/net/ethernet/intel/ice/ice.h \
		'struct ice_vsi {' \
		'struct ice_vsi' source_inferred no yes \
		'VSI groups rings and vectors but is Linux-mutable'
	append_anchor_fixed QueueBind q_vector_object drivers/net/ethernet/intel/ice/ice.h \
		'struct ice_q_vector {' \
		'struct ice_q_vector' source_inferred no yes \
		'q_vector binds NAPI, IRQ, and ring containers'
	append_anchor_fixed QueueBind napi_add drivers/net/ethernet/intel/ice/ice_base.c \
		'netif_napi_add_config(vsi->netdev, &q_vector->napi,' \
		'netif_napi_add_config' source_inferred no yes \
		'NAPI is bound to q_vector but no QueueTag is produced'
	append_anchor_fixed QueueBind map_rings_to_vectors drivers/net/ethernet/intel/ice/ice_base.c \
		'void ice_vsi_map_rings_to_vectors(struct ice_vsi *vsi)' \
		'ice_vsi_map_rings_to_vectors' source_inferred no yes \
		'rings are mapped to q_vectors'
	append_anchor_fixed QueueBind tx_ring_q_vector drivers/net/ethernet/intel/ice/ice_base.c \
		'tx_ring->q_vector = q_vector;' \
		'tx_ring->q_vector' source_inferred no yes \
		'TX ring q_vector mapping exists'
	append_anchor_fixed QueueBind rx_ring_q_vector drivers/net/ethernet/intel/ice/ice_base.c \
		'rx_ring->q_vector = q_vector;' \
		'rx_ring->q_vector' source_inferred no yes \
		'RX ring q_vector mapping exists'

	append_anchor_fixed SubmitLedgerSKB netdev_op drivers/net/ethernet/intel/ice/ice_main.c \
		'.ndo_start_xmit = ice_start_xmit,' \
		'ndo_start_xmit' source_inferred no yes \
		'netdev op binds SKB transmit path'
	append_anchor_fixed SubmitLedgerSKB submit_entry drivers/net/ethernet/intel/ice/ice_txrx.c \
		'netdev_tx_t ice_start_xmit(struct sk_buff *skb, struct net_device *netdev)' \
		'ice_start_xmit' source_inferred yes yes \
		'driver submit entry exists; no SubmitLedger id is allocated'
	append_anchor_fixed SubmitLedgerSKB ring_select drivers/net/ethernet/intel/ice/ice_txrx.c \
		'tx_ring = vsi->tx_rings[skb->queue_mapping];' \
		'skb queue_mapping ring select' source_inferred yes yes \
		'queue_mapping selects a Linux ring, not monitor QueueTag authority'
	append_anchor_fixed SubmitLedgerSKB tx_map drivers/net/ethernet/intel/ice/ice_txrx.c \
		'ice_tx_map(tx_ring, first, &offload);' \
		'ice_tx_map' source_inferred yes yes \
		'SKB submit enters DMA/descriptor map helper'
	append_anchor_fixed SubmitLedgerSKB dma_map_single drivers/net/ethernet/intel/ice/ice_txrx.c \
		'dma = dma_map_single(tx_ring->dev, skb->data, size, DMA_TO_DEVICE);' \
		'SKB dma_map_single' source_inferred yes yes \
		'DMA map anchor without typed submit correlation'
	append_anchor_fixed SubmitLedgerSKB skb_frag_dma_map drivers/net/ethernet/intel/ice/ice_txrx.c \
		'dma = skb_frag_dma_map(tx_ring->dev, frag, 0, size,' \
		'skb_frag_dma_map' source_inferred yes yes \
		'fragment DMA map anchor without typed submit correlation'

	append_anchor_fixed DescriptorLedger descriptor_addr drivers/net/ethernet/intel/ice/ice_txrx.c \
		'tx_desc->buf_addr = cpu_to_le64(dma);' \
		'tx_desc->buf_addr' source_inferred yes yes \
		'descriptor receives DMA address'
	append_anchor_fixed DescriptorLedger descriptor_cmd drivers/net/ethernet/intel/ice/ice_txrx.c \
		'tx_desc->cmd_type_offset_bsz =' \
		'tx_desc->cmd_type_offset_bsz' source_inferred yes yes \
		'descriptor receives command/length flags'
	append_anchor_fixed DescriptorLedger next_to_watch drivers/net/ethernet/intel/ice/ice_txrx.c \
		'first->next_to_watch = tx_desc;' \
		'first->next_to_watch' source_inferred yes yes \
		'completion watch pointer is published'
	append_anchor_fixed DescriptorLedger tx_tail drivers/net/ethernet/intel/ice/ice_txrx.c \
		'writel_relaxed(i, tx_ring->tail);' \
		'TX tail doorbell' source_inferred yes yes \
		'doorbell is driver-specific and not a semantic QueueLease event'

	append_anchor_fixed SubmitLedgerXDPFrame xdp_xmit_op drivers/net/ethernet/intel/ice/ice_main.c \
		'.ndo_xdp_xmit = ice_xdp_xmit,' \
		'ndo_xdp_xmit' source_inferred yes yes \
		'XDP transmit is a distinct submit class'
	append_anchor_fixed SubmitLedgerXDPFrame xdp_submit drivers/net/ethernet/intel/ice/ice_txrx_lib.c \
		'int __ice_xmit_xdp_ring(struct xdp_buff *xdp, struct ice_tx_ring *xdp_ring,' \
		'__ice_xmit_xdp_ring' source_inferred yes yes \
		'XDP frame submit path'
	append_anchor_fixed SubmitLedgerXDPFrame xdp_dma_map drivers/net/ethernet/intel/ice/ice_txrx_lib.c \
		'dma = dma_map_single(dev, data, size, DMA_TO_DEVICE);' \
		'XDP dma_map_single' source_inferred yes yes \
		'XDP frame DMA map anchor'
	append_anchor_fixed SubmitLedgerXDPTxPagePool xdp_page_pool_dma drivers/net/ethernet/intel/ice/ice_txrx_lib.c \
		'dma = page_pool_get_dma_addr(page) + offset;' \
		'page_pool_get_dma_addr' source_inferred yes yes \
		'XDP_TX page-pool reuse needs page-pool ownership semantics'
	append_anchor_fixed SubmitLedgerXDPTxPagePool xdp_tail drivers/net/ethernet/intel/ice/ice_txrx_lib.c \
		'ice_xdp_ring_update_tail(xdp_ring);' \
		'ice_xdp_ring_update_tail' source_inferred yes yes \
		'XDP ring tail update'

	append_anchor_fixed SubmitLedgerAFXDP xsk_wakeup_op drivers/net/ethernet/intel/ice/ice_main.c \
		'.ndo_xsk_wakeup = ice_xsk_wakeup,' \
		'ndo_xsk_wakeup' source_inferred yes yes \
		'AF_XDP wakeup is a distinct submit/control edge'
	append_anchor_fixed SubmitLedgerAFXDP xsk_wakeup drivers/net/ethernet/intel/ice/ice_xsk.c \
		'ice_xsk_wakeup(struct net_device *netdev, u32 queue_id,' \
		'ice_xsk_wakeup' source_inferred yes yes \
		'AF_XDP wakeup entry'
	append_anchor_fixed SubmitLedgerAFXDP xsk_xmit_zc drivers/net/ethernet/intel/ice/ice_xsk.c \
		'bool ice_xmit_zc(struct ice_tx_ring *xdp_ring, struct xsk_buff_pool *xsk_pool)' \
		'ice_xmit_zc' source_inferred yes yes \
		'AF_XDP zero-copy transmit path'
	append_anchor_fixed SubmitLedgerAFXDP xsk_desc_batch drivers/net/ethernet/intel/ice/ice_xsk.c \
		'nb_pkts = xsk_tx_peek_release_desc_batch(xsk_pool, budget);' \
		'xsk_tx_peek_release_desc_batch' source_inferred yes yes \
		'AF_XDP descriptor batch fetch needs XSK/UMEM ownership correlation'

	append_anchor_fixed CompletionSettlement napi_poll drivers/net/ethernet/intel/ice/ice_txrx.c \
		'int ice_napi_poll(struct napi_struct *napi, int budget)' \
		'ice_napi_poll' source_inferred no yes \
		'NAPI poll is completion scheduler, not caller authority'
	append_anchor_fixed CompletionSettlement clean_tx drivers/net/ethernet/intel/ice/ice_txrx.c \
		'static bool ice_clean_tx_irq(struct ice_tx_ring *tx_ring, int napi_budget)' \
		'ice_clean_tx_irq' source_inferred yes yes \
		'TX completion loop'
	append_anchor_fixed CompletionSettlement clean_rx drivers/net/ethernet/intel/ice/ice_txrx.c \
		'static int ice_clean_rx_irq(struct ice_rx_ring *rx_ring, int budget)' \
		'ice_clean_rx_irq' source_inferred yes yes \
		'RX completion loop'
	append_anchor_fixed CompletionSettlement consume_skb drivers/net/ethernet/intel/ice/ice_txrx.c \
		'napi_consume_skb(tx_buf->skb, napi_budget);' \
		'napi_consume_skb' source_inferred yes yes \
		'late SKB lifetime settlement is not full DescriptorLedger settlement'
	append_anchor_fixed CompletionSettlement rx_tail drivers/net/ethernet/intel/ice/ice_txrx_lib.c \
		'writel(val, rx_ring->tail);' \
		'RX tail repost' source_inferred yes yes \
		'RX buffer repost/tail update needs queue memory ownership'

	append_anchor_fixed QueueControl tx_sched_layers drivers/net/ethernet/intel/ice/devlink/devlink.c \
		'static int ice_devlink_tx_sched_layers_set(struct devlink *devlink, u32 id,' \
		'ice_devlink_tx_sched_layers_set' source_inferred yes yes \
		'devlink changes queue scheduling shape'
	append_anchor_fixed QueueControl rate_leaf_share drivers/net/ethernet/intel/ice/devlink/devlink.c \
		'static int ice_devlink_rate_leaf_tx_share_set(struct devlink_rate *rate_leaf, void *priv,' \
		'ice_devlink_rate_leaf_tx_share_set' source_inferred yes yes \
		'devlink rate control needs QueueControlCap'
	append_anchor_fixed QueueControl rate_node_max drivers/net/ethernet/intel/ice/devlink/devlink.c \
		'static int ice_devlink_rate_node_tx_max_set(struct devlink_rate *rate_node, void *priv,' \
		'ice_devlink_rate_node_tx_max_set' source_inferred yes yes \
		'devlink rate control needs QueueControlCap'

	append_anchor_fixed RepresentorForward repr_ops drivers/net/ethernet/intel/ice/ice_repr.c \
		'.ndo_start_xmit = ice_eswitch_port_start_xmit,' \
		'representor ndo_start_xmit' source_inferred yes yes \
		'representor transmit enters eswitch path'
	append_anchor_fixed RepresentorForward repr_xmit drivers/net/ethernet/intel/ice/ice_eswitch.c \
		'ice_eswitch_port_start_xmit(struct sk_buff *skb, struct net_device *netdev)' \
		'ice_eswitch_port_start_xmit' source_inferred yes yes \
		'representor forwarding needs derived lower queue authority'
	append_anchor_fixed RepresentorForward lower_dev_xmit drivers/net/ethernet/intel/ice/ice_eswitch.c \
		'ret = dev_queue_xmit(skb);' \
		'dev_queue_xmit lower dev' source_inferred yes yes \
		'forwarding reinjects into lower device queue path'

	append_anchor_fixed ServiceWork service_task drivers/net/ethernet/intel/ice/ice_main.c \
		'queue_work(ice_wq, &pf->serv_task);' \
		'ice service task queue_work' source_inferred yes yes \
		'service work is not last-caller authority'
	append_anchor_fixed ServiceWork reset_schedule drivers/net/ethernet/intel/ice/ice_main.c \
		'int ice_schedule_reset(struct ice_pf *pf, enum ice_reset_req reset)' \
		'ice_schedule_reset' source_inferred yes yes \
		'reset control-plane work'
	append_anchor_fixed ServiceWork eswitch_bridge_work drivers/net/ethernet/intel/ice/ice_eswitch_br.c \
		'queue_work(br_offloads->wq, &work->work);' \
		'eswitch bridge work' source_inferred yes yes \
		'eswitch bridge work is service/control path'
	append_anchor_fixed ServiceWork ptp_work drivers/net/ethernet/intel/ice/ice_ptp.c \
		'kthread_queue_delayed_work(pf->ptp.kworker, &pf->ptp.work, 0);' \
		'PTP kthread delayed work' source_inferred yes yes \
		'PTP work is service/control path'
}

write_readiness()
{
	printf 'authority_class\tphase\texisting_tracepoints\tsource_anchors\treadiness\tconfidence\trequires_trace_only_patch\trequires_driver_specific_map\tsemantic_gap\tobservation_only\tauthority_claim\tmonitor_verified\n' > "$READINESS"

	append_readiness QueueBind setup \
		'irq_handler_entry/exit,napi_poll' \
		'ice_vsi,ice_q_vector,netif_napi_add_config,ice_vsi_map_rings_to_vectors,ring->q_vector' \
		'partially_ready' source_inferred no yes \
		'No monitor QueueTag, queue epoch, or non-forgeable Domain id exists.'
	append_readiness SubmitLedgerSKB submit \
		'net_dev_start_xmit,net_dev_xmit,ice_xmit_frame_ring' \
		'ice_start_xmit,skb queue_mapping,ice_tx_map,dma_map_single,skb_frag_dma_map' \
		'partial_gap_recorded' partially_observed yes yes \
		'No SubmitLedger id links SKB, DMA maps, descriptors, and tail doorbell.'
	append_readiness SubmitLedgerXDPFrame submit \
		'none_ice_submit_specific' \
		'ndo_xdp_xmit,__ice_xmit_xdp_ring,dma_map_single' \
		'source_only_gap_recorded' source_inferred yes yes \
		'XDP frame submit has source anchors but no typed ledger trace.'
	append_readiness SubmitLedgerXDPTxPagePool submit \
		'none_ice_submit_specific' \
		'page_pool_get_dma_addr,ice_xdp_ring_update_tail' \
		'source_only_gap_recorded' source_inferred yes yes \
		'XDP_TX page-pool reuse lacks page-pool ownership and ledger correlation.'
	append_readiness SubmitLedgerAFXDP submit \
		'none_ice_submit_specific' \
		'ndo_xsk_wakeup,ice_xsk_wakeup,ice_xmit_zc,xsk_tx_peek_release_desc_batch' \
		'source_only_gap_recorded' source_inferred yes yes \
		'AF_XDP zero-copy lacks XSK/UMEM ownership and descriptor ledger correlation.'
	append_readiness DescriptorLedger submit \
		'ice_xmit_frame_ring,ice_clean_tx_irq,ice_clean_tx_irq_unmap' \
		'tx_desc fields,next_to_watch,TX tail doorbell' \
		'partial_gap_recorded' partially_observed yes yes \
		'Tracepoints expose ring/desc/buf around xmit/clean but not typed DescriptorLedger creation.'
	append_readiness CompletionSettlement completion \
		'napi_poll,ice_clean_tx_irq,ice_clean_rx_irq,ice_clean_rx_irq_indicate,consume_skb,kfree_skb' \
		'ice_napi_poll,ice_clean_tx_irq,ice_clean_rx_irq,napi_consume_skb,RX tail repost' \
		'partial_gap_recorded' partially_observed yes yes \
		'Completion lacks typed submit-class settlement and service-budget correlation.'
	append_readiness QueueControl control \
		'none_generic_authority' \
		'ice_devlink_tx_sched_layers_set,devlink rate ops' \
		'source_only_gap_recorded' source_inferred yes yes \
		'Devlink control paths exist but have no QueueControlCap or monitor-owned queue authority.'
	append_readiness RepresentorForward control_data_plane \
		'ice_eswitch bridge tracepoints' \
		'representor ndo_start_xmit,ice_eswitch_port_start_xmit,dev_queue_xmit lower dev' \
		'partial_gap_recorded' partially_observed yes yes \
		'Representor forwarding lacks explicit lower QueueLease derivation evidence.'
	append_readiness ServiceWork service \
		'workqueue tracepoints possible,ice DIM/eswitch tracepoints partial' \
		'ice service task,reset,eswitch bridge work,PTP kthread work' \
		'source_only_gap_recorded' source_inferred yes yes \
		'Service work provenance is service/control, not last-submitter caller authority.'
	append_readiness RevokeSemantics revocation \
		'none_capsched' \
		'driver reset/down/service anchors only' \
		'not_ready_future_capsched' source_inferred yes yes \
		'No CapSched queue revoke epoch, quarantine, or monitor-backed ownership transition exists.'
}

write_gaps()
{
	printf 'gap_id\tauthority_class\tseverity\tevidence\trequired_next_step\n' > "$GAPS"

	append_gap authority-root all high \
		'all observed ice state is Linux-mutable and monitor_verified=false' \
		'never use this readiness output as protection evidence'
	append_gap queue-tag QueueBind high \
		'VSI/ring/q_vector/NAPI anchors exist but no QueueTag or queue epoch is emitted' \
		'define observation-only QueueBind tag before any enforcement prototype'
	append_gap submit-ledger-skb SubmitLedgerSKB high \
		'SKB xmit trace and source anchors do not link skb, DMA maps, descriptors, and tail doorbell' \
		'add trace-only SKB SubmitLedger or targeted probe decoder'
	append_gap submit-ledger-xdp SubmitLedgerXDPFrame high \
		'XDP submit has source anchors but no typed submit ledger tracepoint' \
		'add XDP-specific submit observation or record as non-trace-provable'
	append_gap page-pool-ownership SubmitLedgerXDPTxPagePool high \
		'page_pool_get_dma_addr anchors page-pool DMA reuse without ownership provenance' \
		'model page-pool ownership and add observation-only ownership tag before enforcement'
	append_gap xsk-ownership SubmitLedgerAFXDP high \
		'AF_XDP descriptor batch fetch lacks XSK/UMEM ownership correlation' \
		'model XSK/UMEM ownership and add observation-only AF_XDP submit tag'
	append_gap descriptor-ledger DescriptorLedger high \
		'descriptor field writes and tail doorbell are source-inferred but no typed DescriptorLedger is emitted' \
		'add trace-only descriptor publish and doorbell tags if this path becomes validation target'
	append_gap completion-settlement CompletionSettlement high \
		'ice clean tracepoints expose ring/desc/buf but not submit-class settlement or service budget' \
		'add completion settlement tag or driver-specific decoder tied to SubmitLedger'
	append_gap queue-control QueueControl high \
		'devlink rate/scheduling source anchors exist but no QueueControlCap or monitor QueueTag is checked' \
		'keep QueueControl separate from RunCap and model devlink authority before implementation'
	append_gap representor-derivation RepresentorForward high \
		'representor transmit calls dev_queue_xmit on lower dev without CapSched derivation evidence' \
		'model lower QueueLease derivation and add observation-only representor forward tag'
	append_gap service-provenance ServiceWork high \
		'service/reset/PTP/eswitch work anchors exist but no caller provenance or explicit ServiceOnly classification is emitted' \
		'classify service work as ServiceWork and reject last-submitter BudgetTicket charging'
	append_gap revoke-semantics RevokeSemantics high \
		'reset/down/service paths exist but no CapSched queue revoke epoch or quiescence proof exists' \
		'defer revoke validation until queue epoch/revoke design exists'
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
		echo "source_map=$SOURCE_MAP"
		echo "tracepoints=$TRACEPOINTS"
		echo "source_anchors=$ANCHORS"
		echo "readiness=$READINESS"
		echo "gaps=$GAPS"
		echo "tracepoint_rows=$trace_rows"
		echo "tracepoint_missing_rows=$trace_missing"
		echo "source_anchor_rows=$anchor_rows"
		echo "source_anchor_missing_rows=$anchor_missing"
		echo "class_readiness_rows=$readiness_rows"
		echo "gap_rows=$gap_rows"
		echo "status=observation_only_ice_static_readiness"
	} > "$SUMMARY"
}

require git
require awk
require head
require jq
require wc

jq empty "$SOURCE_MAP"

say "ice modern NIC readiness check started"
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
