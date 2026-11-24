<!-- One character equipment slot (backpack, armor, phone...): caption above a 137px glass tile.
     Slots with an `accepts` rule are real drop targets on the equipment pane; the rest are display-only -->
<script lang="ts">
	import { attemptDrop, dragState, equipSlotAccepts, equipmentPane, equipmentState, hoverTooltipState, itemDataFor, pickUp, quickTransfer, type EquipmentSlotDef } from '../store/inventory.svelte';
	import { Nui } from '../nui';
	import { getItemImage, getItemLabel } from '../util/itemImage';
	import { formatWeight } from '../util/weight';
	import backpackIcon from '../../assets/images/icon-backpack.svg';
	import parachuteIcon from '../../assets/images/icon-parachute.svg';
	import walletIcon from '../../assets/images/wallet.png';
	import keyIcon from '../../assets/images/key.png';
	import armorIcon from '../../assets/images/armor.png';
	import phoneIcon from '../../assets/images/phone.png';
	import type { EquipmentSlotId } from '../types';

	let { def }: { def: EquipmentSlotDef } = $props();
	const id = $derived(def.id);
	const label = $derived(def.label);

	// Placeholder art shown while the slot is empty; vector icons are 52u, raster ones 43u
	const PLACEHOLDERS: Partial<Record<EquipmentSlotId, { src: string; size: number; vector: boolean }>> = {
		backpack: { src: backpackIcon, size: 52, vector: true },
		armor: { src: armorIcon, size: 43, vector: false },
		phone: { src: phoneIcon, size: 43, vector: false },
		parachute: { src: parachuteIcon, size: 52, vector: true },
		wallet: { src: walletIcon, size: 43, vector: false },
		key: { src: keyIcon, size: 43, vector: false },
	};

	const item = $derived(equipmentPane.inventory.find((i) => i?.Slot === def.slot) ?? null);
	const interactive = $derived(!!def.accepts && equipmentPane.loaded);
	const disabled = $derived(!!equipmentPane.disabled[def.slot]);
	const holding = $derived(!!dragState.origin);
	const isDragSource = $derived(dragState.origin?.pane === 'equipment' && dragState.origin?.slot === def.slot);
	// highlight while holding something this slot would take
	const canDrop = $derived(interactive && holding && !isDragSource && !!dragState.held && equipSlotAccepts(def.slot, dragState.held.Name));

	function onMouseUp(e: MouseEvent) {
		if (e.button !== 0 || !interactive || disabled) return;
		if (holding) {
			if (canDrop || isDragSource) attemptDrop('equipment', def.slot);
			else void Nui.frontEndSound('DISABLED');
			return;
		}
		if (!item) return;
		if (e.shiftKey) quickTransfer('equipment', item);
		else pickUp('equipment', item, item.Count);
	}
	const itemData = $derived(item ? itemDataFor(item.Name) : null);
	const keybind = $derived(equipmentState.keybinds[id]);
	const placeholder = $derived(PLACEHOLDERS[id]);
	const weight = $derived(item && itemData ? formatWeight(itemData.weight * item.Count) : '');

	let hovering = $state(false);
	let tileEl = $state<HTMLDivElement | undefined>(undefined);

	$effect(() => {
		if (!hovering || !item || !itemData || holding || !tileEl) return;
		const r = tileEl.getBoundingClientRect();
		hoverTooltipState.info = {
			item,
			itemData,
			shop: false,
			free: false,
			isEligible: true,
			isQualified: true,
			rect: { top: r.top, bottom: r.bottom, left: r.left, right: r.right, width: r.width },
			pane: 'equipment',
		};
		return () => {
			if (hoverTooltipState.info?.item === item) hoverTooltipState.info = null;
		};
	});
</script>

<div class="equip">
	<span class="caption">{label}</span>
	<div
		bind:this={tileEl}
		class="tile"
		class:filled={!!item}
		class:interactive
		class:can-drop={canDrop}
		class:drag-source={isDragSource}
		class:in-flight={disabled}
		onmouseenter={() => (hovering = true)}
		onmouseleave={() => (hovering = false)}
		onmouseup={onMouseUp}
		role="button"
		tabindex="-1"
		aria-label={item && itemData ? `${label}: ${getItemLabel(item, itemData)}` : `${label}: empty`}
	>
		{#if item && itemData}
			<div class="image"><img src={getItemImage(item, itemData)} alt="" loading="lazy" /></div>
			<span class="count">{item.Count}x</span>
			<div class="label">
				<span class="name">{getItemLabel(item, itemData)}</span>
				{#if weight}<span class="weight">{weight}</span>{/if}
			</div>
		{:else if placeholder}
			<img
				class="placeholder"
				src={placeholder.src}
				alt=""
				width={placeholder.size}
				height={placeholder.size}
				style:width={`calc(var(--u) * ${placeholder.size})`}
				style:height={`calc(var(--u) * ${placeholder.size})`}
				style:object-fit={placeholder.vector ? undefined : 'cover'}
			/>
		{/if}
		{#if keybind}
			<span class="keybind">{keybind}</span>
		{/if}
	</div>
</div>

<style>
	.equip {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: calc(var(--u) * 6);
		width: calc(var(--u) * 78);
	}

	.caption {
		font-size: calc(var(--u) * 12);
		font-weight: 700;
		letter-spacing: calc(var(--u) * 1);
		color: var(--glass-text);
		white-space: nowrap;
	}

	.tile {
		--slot-color: #ffffff;
		position: relative;
		/* same 78 x 78 square as the inventory grid slots */
		width: calc(var(--u) * 78);
		height: calc(var(--u) * 78);
		display: flex;
		align-items: center;
		justify-content: center;
		border: calc(var(--u) * 2) solid var(--glass-border);
		border-radius: calc(var(--u) * 8);
		background: var(--glass-bg);
	}

	.tile.filled {
		--slot-color: var(--color-equipped);
		border-color: var(--color-equipped);
	}

	.tile.interactive {
		cursor: pointer;
		transition: border-color 120ms ease, transform 120ms ease, opacity 150ms ease;
	}

	.tile.interactive.filled:hover {
		transform: translateY(calc(var(--u) * -2));
	}

	.tile.can-drop {
		--slot-color: var(--color-primary-light);
		border-color: var(--color-primary-light);
	}

	.tile.can-drop::before {
		opacity: 0.35;
	}

	.tile.drag-source,
	.tile.in-flight {
		opacity: 0.45;
	}

	.tile::before,
	.tile::after {
		content: '';
		position: absolute;
		pointer-events: none;
		border-radius: inherit;
	}

	.tile::before {
		inset: calc(var(--u) * -2);
		box-shadow: 0 0 calc(var(--u) * 25) 0 var(--slot-color), 0 0 calc(var(--u) * 40) 0 var(--slot-color);
		opacity: 0.08;
	}

	.tile.filled::before {
		opacity: 0.16;
	}

	.tile::after {
		inset: 0;
		box-shadow: inset 0 0 calc(var(--u) * 30) 0 var(--slot-color), inset 0 0 calc(var(--u) * 20) 0 var(--slot-color);
		opacity: 0.12;
	}

	.placeholder {
		display: block;
		pointer-events: none;
	}

	.image {
		position: absolute;
		inset: 0;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.image img {
		max-width: 62%;
		max-height: 58%;
		object-fit: contain;
	}

	.count {
		position: absolute;
		top: calc(var(--u) * 3);
		right: calc(var(--u) * 4);
		font-size: calc(var(--u) * 9);
		font-weight: 600;
		line-height: 1;
		color: var(--slot-text);
	}

	.label {
		position: absolute;
		left: calc(var(--u) * 3);
		right: calc(var(--u) * 3);
		bottom: calc(var(--u) * 3);
		display: flex;
		align-items: flex-end;
		justify-content: space-between;
		gap: calc(var(--u) * 2);
		font-weight: 600;
		color: var(--slot-text);
	}

	.name {
		min-width: 0;
		font-size: calc(var(--u) * 9);
		line-height: calc(var(--u) * 11);
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.weight {
		flex-shrink: 0;
		font-size: calc(var(--u) * 8);
		line-height: 1;
	}

	.keybind {
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
	}
</style>
