<!-- One inventory slot: drag/drop shift/ctrl click variants, and the shop storefront card mode -->
<script lang="ts">
	import { fade } from 'svelte/transition';
	import { attemptDrop, cartQtyFor, dragState, getPane, hoverTooltipState, isUsable, itemDataFor, pickUp, playerPane, quickTransfer, setCartQty, useItemAt } from '../store/inventory.svelte';
	import { Nui } from '../nui';
	import { getItemImage, getItemLabel } from '../util/itemImage';
	import { calcDurability } from '../util/durability';
	import { formatShopPrice, getRarityBorderColor, getRarityColor } from '../../config';
	import Icon from '../Icon.svelte';
	import SplitPopover from './SplitPopover.svelte';
	import type { InventorySlotItem, PaneId } from '../types';

	let { pane, slotNumber, item }: { pane: PaneId; slotNumber: number; item: InventorySlotItem | null } = $props();

	const paneState = $derived(getPane(pane));
	const shopMode = $derived(!!paneState.shop);
	const itemData = $derived(item ? itemDataFor(item.Name) : null);
	const durability = $derived(item && itemData ? calcDurability(item.CreateDate, itemData.durability) : null);
	const broken = $derived(durability != null && durability <= 0);
	const DURABILITY_TICKS = 5;
	const durabilityFilled = $derived(durability != null ? Math.max(1, Math.ceil((durability / 100) * DURABILITY_TICKS)) : 0);
	const durabilityColor = $derived(durability == null ? '' : durability >= 60 ? 'var(--color-success)' : durability >= 25 ? 'var(--color-warning)' : 'var(--color-error)');
	const disabled = $derived(!!paneState.disabled[slotNumber]);

	const usable = $derived(item ? isUsable(pane, item) : false);
	const holding = $derived(!!dragState.origin);
	const isDragSource = $derived(dragState.origin?.pane === pane && dragState.origin?.slot === slotNumber);

	const weaponLocked = $derived(shopMode && !!itemData?.requiresLicense && itemData?.type === 2 && !playerPane.isWeaponEligble);
	const qualiLocked = $derived(shopMode && !!itemData?.qualification && !(playerPane.qualifications ?? []).includes(itemData.qualification));
	const locked = $derived(weaponLocked || qualiLocked);

	// Per-unit price, not price × stock count
	const unitPrice = $derived(item && itemData ? (item.Price ?? itemData.price) : 0);
	const isFree = $derived(!!paneState.free || !unitPrice);

	const cartQty = $derived(item ? cartQtyFor(item.Slot) : 0);

	function adjustCart(e: MouseEvent, delta: number) {
		e.stopPropagation();
		if (!item || locked) return;
		setCartQty(item, unitPrice, cartQty + delta);
	}

	let hovering = $state(false);
	let splitOpen = $state(false);
	let slotEl = $state<HTMLDivElement | undefined>(undefined);
	let showConfirm = $state(false);
	let confirmTimer: ReturnType<typeof setTimeout> | undefined;

	// flashes a checkmark the moment `disabled` (server verifying the move) flips back off
	$effect(() => {
		if (!disabled) return;
		return () => {
			clearTimeout(confirmTimer);
			showConfirm = true;
			confirmTimer = setTimeout(() => (showConfirm = false), 450);
		};
	});

	// Item art stays hidden for the whole verifying+confirming stretch, then fades back in
	const inFlight = $derived(disabled || showConfirm);

	// Syncs the shared, Shell-level hover tooltip instead of rendering one inline here
	$effect(() => {
		if (!hovering || !item || !itemData || holding || splitOpen || !slotEl) return;
		const r = slotEl.getBoundingClientRect();
		hoverTooltipState.info = {
			item,
			itemData,
			shop: shopMode,
			free: !!paneState.free,
			isEligible: !weaponLocked,
			isQualified: !qualiLocked,
			rect: { top: r.top, bottom: r.bottom, left: r.left, right: r.right, width: r.width },
		};
		return () => {
			if (hoverTooltipState.info?.item === item) hoverTooltipState.info = null;
		};
	});

	// Left mouseup: completes a drop if holding, else starts a pickup (shift = quick-transfer)
	function onMouseUp(e: MouseEvent) {
		if (locked || e.button !== 0) return;

		if (holding) {
			attemptDrop(pane, slotNumber);
			return;
		}

		// Shop stock buys via the cart controls, not click/drag
		if (shopMode || !item) return;

		if (e.shiftKey) {
			quickTransfer(pane, item);
			return;
		}

		const typed = dragState.draggingAmount;
		const count = typed > 0 && typed < item.Count ? typed : item.Count;
		pickUp(pane, item, count);
	}

	function onMouseDown(e: MouseEvent) {
		if (locked || shopMode || !item) return;
		if (e.button === 1) {
			e.preventDefault();
			if (usable) {
				useItemAt(pane, item);
			} else {
				void Nui.frontEndSound('DISABLED');
			}
		}
	}

	// Right-click: Ctrl = single unit, Shift = split popover, plain = half stack
	function onContextMenu(e: MouseEvent) {
		e.preventDefault();
		if (locked || holding || shopMode || !item) return;

		if (e.ctrlKey || !itemData?.isStackable) {
			pickUp(pane, item, 1);
		} else if (e.shiftKey) {
			// Clear the tooltip synchronously so it can't flash over the popover
			if (hoverTooltipState.info?.item === item) hoverTooltipState.info = null;
			splitOpen = true;
		} else {
			pickUp(pane, item, Math.max(1, Math.min(Math.floor(item.Count / 2), 10000)));
		}
	}
</script>

<div
	bind:this={slotEl}
	class="slot"
	class:shop={shopMode}
	class:empty={!item}
	class:broken
	class:disabled
	class:locked
	class:drag-source={isDragSource}
	class:split-open={splitOpen}
	style:border-color={item && itemData && !broken && !shopMode ? getRarityBorderColor(itemData.rarity) : undefined}
	onmousedown={onMouseDown}
	onmouseup={onMouseUp}
	oncontextmenu={onContextMenu}
	onmouseenter={() => (hovering = true)}
	onmouseleave={() => (hovering = false)}
	role="button"
	tabindex="0"
>
	{#if item && itemData}
		{#if shopMode}
			<div class="shop-icon-wrap">
				<img class="shop-icon" src={getItemImage(item, itemData)} alt="" loading="lazy" />
			</div>
			<div class="shop-info">
				<div class="shop-name" style:color={getRarityColor(itemData.rarity)}>{getItemLabel(item, itemData)}</div>
				<div class="shop-stock">{item.Count} in stock</div>
			</div>
			<div class="shop-price" class:free={isFree}>
				{#if isFree}
					<Icon name="circle-check" size="0.9vmin" />
					<span>Free</span>
				{:else}
					<Icon name="dollar-sign" size="0.85vmin" />
					<span>{formatShopPrice(unitPrice)}</span>
				{/if}
			</div>
			<div class="shop-cart-row" onmousedown={(e) => e.stopPropagation()} onmouseup={(e) => e.stopPropagation()} oncontextmenu={(e) => e.stopPropagation()} role="presentation">
				{#if cartQty > 0}
					<button type="button" class="qty-btn" onclick={(e) => adjustCart(e, -1)}>
						<Icon name="minus" size="0.7vmin" />
					</button>
					<span class="qty-val">{cartQty}</span>
					<button type="button" class="qty-btn" disabled={cartQty >= item.Count} onclick={(e) => adjustCart(e, 1)}>
						<Icon name="plus" size="0.7vmin" />
					</button>
				{:else}
					<button type="button" class="add-btn" onclick={(e) => adjustCart(e, 1)}>
						<Icon name="plus" size="0.7vmin" />
						<span>Add to Cart</span>
					</button>
				{/if}
			</div>
		{:else}
			<div class="image" class:in-flight={inFlight}><img src={getItemImage(item, itemData)} alt="" loading="lazy" /></div>
			<div class="label" class:in-flight={inFlight}>
				<span class="name">{getItemLabel(item, itemData)}</span>
			</div>
			{#if item.Count > 1}
				<div class="count" class:in-flight={inFlight}>{item.Count}</div>
			{/if}
		{/if}

		{#if !shopMode && itemData.durability && item.CreateDate && !broken && durability != null}
			<div class="durability-meter" style:color={durabilityColor}>
				{#each { length: DURABILITY_TICKS } as _, i (i)}
					<span class="tick" class:filled={i < durabilityFilled}></span>
				{/each}
			</div>
		{/if}
		{#if disabled}
			<div class="spinner" transition:fade={{ duration: 150 }}></div>
		{:else if showConfirm}
			<div class="confirm" transition:fade={{ duration: 150 }}>
				<span class="confirm-icon"><Icon name="check" size="1.6vmin" /></span>
			</div>
		{/if}
		{#if splitOpen}
			<div class="split-anchor">
				<SplitPopover {pane} {item} onClose={() => (splitOpen = false)} />
			</div>
		{/if}
	{/if}
</div>

<style>
	.slot {
		position: relative;
		width: 4.6vw;
		height: 9.5vh;
		min-width: 58px;
		min-height: 58px;
		border: 1px solid rgba(255, 255, 255, 0.08);
		border-radius: 2px;
		background: rgba(32, 34, 45, 0.75);
		box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.4), inset 0 0 0 1px rgba(255, 255, 255, 0.02);
		cursor: pointer;
		overflow: visible;
		transition: transform 120ms ease, border-color 120ms ease, box-shadow 120ms ease;
	}

	.slot.empty {
		border-color: rgba(255, 255, 255, 0.05);
		background: rgba(18, 19, 25, 0.4);
		box-shadow: inset 0 1px 3px rgba(0, 0, 0, 0.35);
		cursor: default;
	}

	.slot.broken {
		background: rgba(220, 53, 69, 0.18);
		border-color: rgba(220, 53, 69, 0.4);
	}

	.slot.locked {
		cursor: not-allowed;
		opacity: 0.5;
	}

	.slot.drag-source {
		opacity: 0.4;
	}

	/* no transform while split-open: transform on this element would make it the containing
	   block for the popover's fixed backdrop, so it'd stop covering the full screen */
	.slot:not(.empty):not(.locked):not(.split-open):hover {
		transform: translateY(-2px);
		border-color: rgba(255, 255, 255, 0.18);
		box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.4), 0 6px 14px rgba(0, 0, 0, 0.35);
	}

	.image {
		position: absolute;
		inset: 0;
		display: flex;
		align-items: center;
		justify-content: center;
		opacity: 1;
		transition: opacity 200ms ease;
	}

	.image.in-flight {
		opacity: 0;
	}

	.image img {
		max-width: 65%;
		max-height: 65%;
		object-fit: contain;
	}

	.label {
		position: absolute;
		bottom: 0;
		left: 0;
		right: 0;
		text-align: center;
		padding: 0.5vh 0.2vw;
		background: linear-gradient(to top, rgba(0, 0, 0, 0.78) 0%, rgba(0, 0, 0, 0) 100%);
		opacity: 1;
		transition: opacity 200ms ease;
	}

	.label.in-flight {
		opacity: 0;
	}

	.label .name {
		width: 100%;
		font-size: 0.85vmin;
		font-weight: 500;
		color: var(--color-text);
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.count {
		position: absolute;
		top: 0.4vh;
		right: 0.3vw;
		padding: 0.15vh 0.35vw;
		font-size: 0.9vmin;
		font-weight: 600;
		color: var(--color-text);
		background: rgba(0, 0, 0, 0.5);
		border-radius: 4px;
		opacity: 1;
		transition: opacity 200ms ease;
	}

	.count.in-flight {
		opacity: 0;
	}

	.durability-meter {
		position: absolute;
		bottom: 2.6vh;
		left: 0;
		width: 100%;
		display: flex;
		gap: 1.5px;
		padding: 0 0.3vw;
	}

	.tick {
		flex: 1;
		height: 3px;
		border-radius: 1px;
		background: rgba(0, 0, 0, 0.35);
		transition: background 200ms ease;
	}

	.tick.filled {
		background: currentColor;
	}

	.spinner {
		position: absolute;
		inset: 0;
		margin: auto;
		width: 2vh;
		height: 2vh;
		border: 2px solid rgba(139, 92, 246, 0.25);
		border-top-color: var(--color-primary);
		border-radius: 50%;
		animation: spin 700ms linear infinite;
	}

	.confirm {
		position: absolute;
		inset: 0;
		display: flex;
		align-items: center;
		justify-content: center;
		color: var(--color-primary-light);
		background: rgba(0, 0, 0, 0.35);
	}

	.confirm-icon {
		display: flex;
		animation: confirmPop 350ms cubic-bezier(0.2, 1.4, 0.4, 1) forwards;
	}

	@keyframes confirmPop {
		0% {
			transform: scale(0.5);
		}
		60% {
			transform: scale(1.15);
		}
		100% {
			transform: scale(1);
		}
	}

	@keyframes spin {
		to {
			transform: rotate(360deg);
		}
	}

	.split-anchor {
		position: absolute;
		top: 100%;
		left: 50%;
		transform: translateX(-50%);
		margin-top: 0.6vh;
		z-index: 210;
	}

	.slot.shop {
		width: 7.6vw;
		height: 17.4vh;
		min-width: 106px;
		min-height: 172px;
		display: flex;
		flex-direction: column;
		background: rgba(28, 29, 38, 0.85);
		border-color: rgba(255, 255, 255, 0.09);
		cursor: default;
	}

	/* no lift-on-hover, shop cards aren't click/drag targets */
	.slot.shop:hover,
	.slot.shop:not(.empty):not(.locked):hover {
		transform: none;
		border-color: rgba(255, 255, 255, 0.2);
		box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.4), inset 0 0 0 1px rgba(255, 255, 255, 0.02);
	}

	.shop-icon-wrap {
		flex: 1;
		min-height: 0;
		display: flex;
		align-items: center;
		justify-content: center;
		border-bottom: 1px solid rgba(255, 255, 255, 0.06);
	}

	.shop-icon {
		max-width: 66%;
		max-height: 66%;
		object-fit: contain;
		filter: drop-shadow(0 3px 6px rgba(0, 0, 0, 0.5));
	}

	.shop-info {
		flex-shrink: 0;
		padding: 0.8vh 0.7vw 0.5vh;
		text-align: center;
	}

	.shop-name {
		font-size: 0.95vmin;
		font-weight: 600;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.shop-stock {
		margin-top: 0.2vh;
		font-size: 0.88vmin;
		color: var(--color-text-muted);
	}

	.shop-price {
		flex-shrink: 0;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.3vw;
		margin: 0 0.6vw 0.6vh;
		padding: 0.5vh 0;
		border-top: 1px solid rgba(255, 255, 255, 0.06);
		font-size: 0.9vmin;
		font-weight: 700;
		color: var(--color-success);
	}

	.shop-price.free {
		color: var(--color-primary-light);
	}

	.shop-cart-row {
		flex-shrink: 0;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.4vw;
		margin: 0 0.6vw 0.7vh;
	}

	.add-btn {
		width: 100%;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.3vw;
		padding: 0.5vh 0;
		border: 1px solid rgba(255, 255, 255, 0.1);
		border-radius: var(--radius);
		background: rgba(255, 255, 255, 0.03);
		color: var(--color-text-muted);
		font-size: 0.78vmin;
		font-weight: 600;
		cursor: pointer;
		transition: border-color 120ms ease, color 120ms ease, background 120ms ease;
	}

	.add-btn:hover {
		border-color: rgba(139, 92, 246, 0.4);
		color: var(--color-primary-light);
		background: rgba(139, 92, 246, 0.1);
	}

	.qty-btn {
		width: 2.4vh;
		height: 2.4vh;
		min-width: 22px;
		min-height: 22px;
		display: flex;
		align-items: center;
		justify-content: center;
		border: none;
		border-radius: 4px;
		background: rgba(139, 92, 246, 0.16);
		color: var(--color-primary-light);
		cursor: pointer;
		transition: background 120ms ease;
	}

	.qty-btn:hover:not(:disabled) {
		background: rgba(139, 92, 246, 0.32);
	}

	.qty-btn:disabled {
		opacity: 0.3;
		cursor: not-allowed;
	}

	.qty-val {
		min-width: 1.8vw;
		text-align: center;
		font-size: 0.9vmin;
		font-weight: 700;
		color: var(--color-text);
		font-variant-numeric: tabular-nums;
	}
</style>
