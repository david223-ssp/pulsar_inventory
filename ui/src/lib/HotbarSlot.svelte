<!-- Read-only hotbar slot display: numbered slots 1-5 plus an optional larger "Equipped" slot -->
<script lang="ts">
	import { itemDataFor } from './store/inventory.svelte';
	import { getItemImage, getItemLabel } from './util/itemImage';
	import { calcDurability } from './util/durability';
	import { getRarityBorderColor } from '../config';
	import type { InventorySlotItem } from './types';

	let { item, slot, equipped = false }: { item: InventorySlotItem | null; slot?: number; equipped?: boolean } = $props();

	const itemData = $derived(item ? itemDataFor(item.Name) : null);
	const durability = $derived(item && itemData ? calcDurability(item.CreateDate, itemData.durability) : null);
	const broken = $derived(durability != null && durability <= 0);
	const DURABILITY_TICKS = 5;
	const durabilityFilled = $derived(durability != null ? Math.max(1, Math.ceil((durability / 100) * DURABILITY_TICKS)) : 0);
	const durabilityColor = $derived(durability == null ? '' : durability >= 60 ? 'var(--color-success)' : durability >= 25 ? 'var(--color-warning)' : 'var(--color-error)');
</script>

{#if equipped}
	<div class="equipped-wrap">
		<div class="ring" class:broken>
			<div class="image">
				{#if itemData}
					<img src={getItemImage(item, itemData)} alt="" loading="lazy" />
				{/if}
			</div>
		</div>
		{#if itemData}
			<div class="equipped-caption">
				<span class="tag">Equipped</span>
				<span class="name">{getItemLabel(item, itemData)}</span>
			</div>
		{/if}
	</div>
{:else}
	<div class="slot" class:empty={!item} class:broken style:border-color={item && itemData && !broken ? getRarityBorderColor(itemData.rarity) : undefined}>
		{#if slot}
			<span class="badge number">{slot}</span>
		{/if}

		{#if item && item.Count > 1}
			<span class="badge count">{item.Count}</span>
		{/if}

		<div class="image">
			{#if itemData}
				<img src={getItemImage(item, itemData)} alt="" loading="lazy" />
			{/if}
		</div>

		{#if itemData}
			<div class="label">{getItemLabel(item, itemData)}</div>
		{/if}

		{#if itemData?.durability && item?.CreateDate && durability != null && durability > 0}
			<div class="durability-meter" style:color={durabilityColor}>
				{#each { length: DURABILITY_TICKS } as _, i (i)}
					<span class="tick" class:filled={i < durabilityFilled}></span>
				{/each}
			</div>
		{/if}
	</div>
{/if}

<style>
	/* ---- Regular numbered slots ---- */
	.slot {
		position: relative;
		width: 7.2vh;
		height: 7.2vh;
		min-width: 64px;
		min-height: 64px;
		flex-shrink: 0;
		pointer-events: none;
		background: rgba(20, 18, 28, 0.9);
		border: 1px solid rgba(255, 255, 255, 0.1);
		border-radius: 2px;
		box-shadow: 0 8px 20px rgba(0, 0, 0, 0.4), inset 0 1px 2px rgba(0, 0, 0, 0.4);
		overflow: hidden;
	}

	.slot.empty {
		background: rgba(14, 13, 19, 0.6);
		border-color: rgba(255, 255, 255, 0.06);
	}

	.slot.broken {
		background: rgba(220, 53, 69, 0.18);
		border-color: rgba(220, 53, 69, 0.4) !important;
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
		max-height: 62%;
		object-fit: contain;
		filter: drop-shadow(0 2px 4px rgba(0, 0, 0, 0.5));
	}

	.label {
		position: absolute;
		bottom: 0;
		left: 0;
		right: 0;
		text-align: center;
		padding: 0.5vh 0.3vw;
		font-size: 0.8vmin;
		font-weight: 500;
		color: var(--color-text);
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
		background: linear-gradient(to top, rgba(0, 0, 0, 0.75) 0%, rgba(0, 0, 0, 0) 100%);
	}

	.badge {
		position: absolute;
		top: 0.4vh;
		z-index: 1;
		display: flex;
		align-items: center;
		justify-content: center;
		border-radius: 4px;
		background: rgba(0, 0, 0, 0.55);
		font-size: 0.85vmin;
		font-weight: 600;
		color: var(--color-text-muted);
	}

	.badge.number {
		left: 0.4vh;
		width: 1.8vh;
		height: 1.8vh;
	}

	.badge.count {
		right: 0.4vh;
		padding: 0.1vh 0.35vw;
		color: var(--color-text);
	}

	.durability-meter {
		position: absolute;
		bottom: 2vh;
		left: 0;
		width: 100%;
		display: flex;
		gap: 1.5px;
		padding: 0 0.4vh;
	}

	.tick {
		flex: 1;
		height: 3px;
		border-radius: 1px;
		background: rgba(0, 0, 0, 0.35);
	}

	.tick.filled {
		background: currentColor;
	}

	.equipped-wrap {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 0.7vh;
		pointer-events: none;
	}

	.ring {
		position: relative;
		width: 8.4vh;
		height: 8.4vh;
		min-width: 72px;
		min-height: 72px;
		border-radius: 2px;
		background: rgba(16, 15, 22, 0.95);
		border: 2px solid var(--color-success);
		box-shadow: 0 8px 20px rgba(0, 0, 0, 0.4);
	}

	.ring.broken {
		border-color: var(--color-error);
	}

	.ring .image {
		inset: 12%;
	}

	.ring .image img {
		max-width: 78%;
		max-height: 78%;
	}

	.equipped-caption {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 0.15vh;
		max-width: 11vh;
	}

	.equipped-caption .tag {
		font-size: 0.75vmin;
		font-weight: 700;
		letter-spacing: 0.06em;
		text-transform: uppercase;
		color: var(--color-warning);
		text-shadow: 0 0 6px rgba(0, 0, 0, 0.8);
	}

	.equipped-caption .name {
		font-size: 0.9vmin;
		font-weight: 600;
		color: var(--color-text);
		text-shadow: 0 0 6px rgba(0, 0, 0, 0.8);
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
		max-width: 11vh;
	}
</style>
