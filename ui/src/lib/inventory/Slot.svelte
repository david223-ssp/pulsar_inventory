<!-- One inventory slot: drag/drop shift/ctrl click variants, and the shop storefront card mode -->
<script lang="ts">
	import { fade } from 'svelte/transition';
	import { attemptDrop, cartQtyFor, dragState, getPane, hoverTooltipState, isUsable, itemDataFor, pickUp, playerPane, quickTransfer, setCartQty, useItemAt } from '../store/inventory.svelte';
	import { Nui } from '../nui';
	import { getItemImage, getItemLabel } from '../util/itemImage';
	import { formatWeight } from '../util/weight';
	import { calcDurability } from '../util/durability';
	import { formatShopPrice, getRarityBorderColor, getRarityColor } from '../../config';
	import Icon from '../Icon.svelte';
	import SplitPopover from './SplitPopover.svelte';
	import { contextMenuState, isFavourite, openContextMenu } from '../menu/menuState.svelte';
	import TablerIcon from '../menu/TablerIcon.svelte';
	import type { InventorySlotItem, PaneId } from '../types';

	let { pane, slotNumber, item, showNumber = false }: { pane: PaneId; slotNumber: number; item: InventorySlotItem | null; showNumber?: boolean } = $props();

	const paneState = $derived(getPane(pane));
	const shopMode = $derived(!!paneState.shop);
	const itemData = $derived(item ? itemDataFor(item.Name) : null);
	const durability = $derived(item && itemData ? calcDurability(item.CreateDate, itemData.durability) : null);
	const broken = $derived(durability != null && durability <= 0);
	const DURABILITY_TICKS = 5;
	const durabilityFilled = $derived(durability != null ? Math.max(1, Math.ceil((durability / 100) * DURABILITY_TICKS)) : 0);
	const durabilityColor = $derived(durability == null ? '' : durability >= 60 ? 'var(--color-success)' : durability >= 25 ? 'var(--color-warning)' : 'var(--color-error)');
	const disabled = $derived(!!paneState.disabled[slotNumber]);
	const rarityColor = $derived(item && itemData && !broken && !shopMode ? getRarityBorderColor(itemData.rarity) : undefined);
	const stackWeight = $derived(item && itemData ? formatWeight(itemData.weight * item.Count) : '');

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
			pane,
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

	// the context menu's "Split Stack" lands here
	$effect(() => {
		const req = contextMenuState.splitRequest;
		if (!req || req.pane !== pane || req.slot !== slotNumber || !item) return;
		contextMenuState.splitRequest = null;
		if (hoverTooltipState.info?.item === item) hoverTooltipState.info = null;
		splitOpen = true;
	});

	// Right-click: plain = item menu on your own pockets/backpack (like ox_inventory), half stack elsewhere;
	// Ctrl = single unit, Shift = split popover
	function onContextMenu(e: MouseEvent) {
		e.preventDefault();
		if (locked || holding || shopMode || !item) return;

		if (!e.ctrlKey && !e.shiftKey && (pane === 'player' || pane === 'backpack')) {
			if (hoverTooltipState.info?.item === item) hoverTooltipState.info = null;
			openContextMenu(pane, item, e.clientX, e.clientY);
			return;
		}

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
	class:rarity={!!rarityColor}
	style:--slot-color={rarityColor}
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
			<div class="count" class:in-flight={inFlight}>{item.Count}x</div>
			<div class="label" class:in-flight={inFlight}>
				<span class="name">{getItemLabel(item, itemData)}</span>
				{#if stackWeight}
					<span class="weight">{stackWeight}</span>
				{/if}
			</div>
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
	{#if showNumber && !shopMode}
		<span class="number">{slotNumber}</span>
	{/if}
	{#if item && !shopMode && isFavourite(item.Name)}
		<span class="favourite" title="Favourite"><TablerIcon name="star" /></span>
	{/if}
</div>

<style>
	/* 1 design px = var(--u); see theme.css */
	.slot {
		--slot-color: #ffffff;
		position: relative;
		width: 100%;
		height: 100%;
		border: calc(var(--u) * 2) solid var(--glass-border);
		border-radius: calc(var(--u) * 8);
		background: var(--glass-bg);
		cursor: pointer;
		overflow: visible;
		transition: transform 120ms ease, border-color 120ms ease;
	}

	.slot.rarity {
		border-color: var(--slot-color);
	}

	/* outer + inner glow tinted by the rarity color; split into pseudo-elements so a CSS-var color can be faded with opacity */
	.slot::before,
	.slot::after {
		content: '';
		position: absolute;
		pointer-events: none;
		border-radius: inherit;
	}

	.slot::before {
		inset: calc(var(--u) * -2);
		box-shadow: 0 0 calc(var(--u) * 25) 0 var(--slot-color), 0 0 calc(var(--u) * 40) 0 var(--slot-color);
		opacity: 0.08;
	}

	.slot.rarity::before {
		opacity: 0.16;
	}

	.slot::after {
		inset: 0;
		box-shadow: inset 0 0 calc(var(--u) * 30) 0 var(--slot-color), inset 0 0 calc(var(--u) * 20) 0 var(--slot-color);
		opacity: 0.12;
	}

	.slot.empty {
		cursor: default;
	}

	.slot.broken {
		--slot-color: var(--color-error);
		border-color: rgba(220, 53, 69, 0.6);
		background: rgba(80, 20, 25, 0.55);
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
	.slot:not(.empty):not(.locked):not(.split-open):not(.shop):hover {
		transform: translateY(calc(var(--u) * -2));
	}

	.slot:not(.empty):not(.rarity):not(.shop):hover {
		border-color: #bdbdbd;
	}

	.favourite {
		position: absolute;
		top: calc(var(--u) * 16);
		right: calc(var(--u) * 3);
		width: calc(var(--u) * 10);
		height: calc(var(--u) * 10);
		color: var(--color-primary-light);
		pointer-events: none;
		z-index: 1;
	}

	.favourite :global(svg) {
		width: 100%;
		height: 100%;
		fill: currentColor;
	}

	.number {
		position: absolute;
		top: 0;
		left: 0;
		height: calc(var(--u) * 16);
		padding: calc(var(--u) * 3);
		display: flex;
		align-items: center;
		border: calc(var(--u) * 1) solid rgba(255, 255, 255, 0.3);
		border-radius: calc(var(--u) * 6) 0 calc(var(--u) * 8) 0;
		background: var(--slot-badge-bg);
		box-shadow: 0 calc(var(--u) * 2) calc(var(--u) * 4) rgba(0, 0, 0, 0.2);
		font-size: calc(var(--u) * 9);
		font-weight: 600;
		line-height: 1;
		color: var(--slot-badge-text);
		pointer-events: none;
		z-index: 1;
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
		max-width: 62%;
		max-height: 58%;
		object-fit: contain;
	}

	.label {
		position: absolute;
		left: calc(var(--u) * 3);
		right: calc(var(--u) * 3);
		bottom: calc(var(--u) * 3);
		display: flex;
		align-items: flex-end;
		justify-content: space-between;
		gap: calc(var(--u) * 4);
		font-weight: 600;
		color: var(--slot-text);
		opacity: 1;
		transition: opacity 200ms ease;
	}

	.label.in-flight {
		opacity: 0;
	}

	.label .name {
		min-width: 0;
		font-size: calc(var(--u) * 9);
		line-height: calc(var(--u) * 11);
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.label .weight {
		flex-shrink: 0;
		font-size: calc(var(--u) * 8);
		line-height: 1;
	}

	.count {
		position: absolute;
		top: calc(var(--u) * 3);
		right: calc(var(--u) * 4);
		font-size: calc(var(--u) * 9);
		font-weight: 600;
		line-height: 1;
		color: var(--slot-text);
		opacity: 1;
		transition: opacity 200ms ease;
	}

	.count.in-flight {
		opacity: 0;
	}

	.durability-meter {
		position: absolute;
		bottom: calc(var(--u) * 16);
		left: 0;
		width: 100%;
		display: flex;
		gap: calc(var(--u) * 2);
		padding: 0 calc(var(--u) * 4);
	}

	.tick {
		flex: 1;
		height: calc(var(--u) * 2);
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
		width: calc(var(--u) * 22);
		height: calc(var(--u) * 22);
		border: calc(var(--u) * 2) solid rgba(139, 92, 246, 0.25);
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
		border-radius: inherit;
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
		margin-top: calc(var(--u) * 8);
		z-index: 210;
	}

	.slot.shop {
		display: flex;
		flex-direction: column;
		cursor: default;
	}

	/* no lift-on-hover, shop cards aren't click/drag targets */
	.slot.shop:hover {
		border-color: #bdbdbd;
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
