<!-- One recipe card: output slot, ingredients, qty stepper, throttled craft button, cooldown overlay -->
<script lang="ts">
	import { CRAFT_THROTTLE_MS, getRarityColor } from '../../config';
	import { Nui } from '../nui';
	import { applyCraftResult, craftingState, itemDataFor, playerPane } from '../store/inventory.svelte';
	import { throttle } from '../util/throttle';
	import { formatDuration } from '../util/duration';
	import { getItemImage, getItemLabel } from '../util/itemImage';
	import Icon from '../Icon.svelte';
	import type { Recipe } from '../types';

	let { recipe, cooldown, oncraftingchange }: { recipe: Recipe; cooldown: number | undefined; oncraftingchange: (crafting: boolean) => void } = $props();

	const outputItem = $derived(itemDataFor(recipe.result.name));
	const max = $derived(outputItem.isStackable ? Math.floor(outputItem.isStackable / recipe.result.count) : 1);
	const accent = $derived(getRarityColor(outputItem.rarity));

	let qty = $state(1);
	let crafting = $state(false);
	let now = $state(Date.now());

	$effect(() => {
		const interval = setInterval(() => (now = Date.now()), 1000);
		return () => clearInterval(interval);
	});

	const onCooldown = $derived(!!cooldown && cooldown > now);

	const counts = $derived.by(() => {
		const map: Record<string, number> = {};
		for (const slot of playerPane.inventory) {
			if (!slot) continue;
			map[slot.Name] = (map[slot.Name] ?? 0) + slot.Count;
		}
		return map;
	});

	const reagents = $derived.by(() => {
		const map: Record<string, number> = {};
		for (const mat of recipe.items) map[mat.name] = (map[mat.name] ?? 0) + mat.count;
		return map;
	});

	const playerWeight = $derived(playerPane.inventory.reduce((sum, i) => (i ? sum + itemDataFor(i.Name).weight * i.Count : sum), 0));
	const overweight = $derived(playerWeight + outputItem.weight * recipe.result.count * qty > playerPane.capacity);

	const hasReagents = $derived(Object.entries(reagents).every(([name, needed]) => (counts[name] ?? 0) >= needed * qty));

	const canCraft = $derived(!crafting && hasReagents && !onCooldown && !overweight);

	const craftLabel = $derived(crafting ? 'Crafting…' : !hasReagents ? 'Missing Reagents' : overweight ? 'Too Heavy' : 'Craft');

	function adjustQty(delta: number) {
		if (onCooldown) return;
		const next = qty + delta;
		if (next < 1 || next > max) return;
		qty = next;
	}

	const doCraft = throttle(async () => {
		if (overweight || crafting) return;
		crafting = true;
		oncraftingchange(true);
		try {
			const res = await Nui.craft(craftingState.bench, qty, recipe.id);
			if (res) {
				if (res.inventory) applyCraftResult(res.inventory, res.cooldowns ?? {});
				qty = 1;
			}
		} finally {
			crafting = false;
			oncraftingchange(false);
		}
	}, CRAFT_THROTTLE_MS);
</script>

<div class="card">
	{#if onCooldown && cooldown}
		<div class="cooldown-overlay">
			<Icon name="ban" size="1.6vmin" />
			<div class="inner">
				<span class="cd-label">On Cooldown</span>
				<span class="time">{formatDuration(cooldown - now)}</span>
			</div>
		</div>
	{/if}

	<div class="header">
		<div class="icon"><img src={getItemImage(null, outputItem)} alt="" loading="lazy" /></div>
		<div class="title">
			<span class="name" style:color={accent}>{getItemLabel(null, outputItem)}</span>
			{#if recipe.result.count > 0}
				<span class="yield">Makes ×{recipe.result.count * qty}</span>
			{/if}
		</div>
	</div>

	<div class="mats">
		{#each Object.entries(reagents) as [name, needed] (name)}
			{@const matData = itemDataFor(name)}
			{@const have = counts[name] ?? 0}
			{@const enough = have >= needed * qty}
			<div class="mat-row" class:missing={!enough}>
				<span class="mat-icon"><img src={getItemImage(null, matData)} alt="" loading="lazy" /></span>
				<span class="mat-name">{matData.label}</span>
				<span class="mat-frac">{have}/{needed * qty}</span>
			</div>
		{/each}
	</div>

	<div class="footer">
		{#if max > 1}
			<div class="stepper">
				<button type="button" disabled={onCooldown || qty <= 1} onclick={() => adjustQty(-1)} aria-label="Decrease quantity"><Icon name="minus" size="0.85vmin" /></button>
				<span>{qty}</span>
				<button type="button" disabled={onCooldown || qty >= max} onclick={() => adjustQty(1)} aria-label="Increase quantity"><Icon name="plus" size="0.85vmin" /></button>
			</div>
		{/if}
		<button type="button" class="craft-btn" class:ready={canCraft} disabled={!canCraft} onclick={doCraft}>
			{#if crafting}
				<span class="spinner"></span>
			{:else}
				<Icon name={!hasReagents ? 'ban' : overweight ? 'weight-hanging' : 'hammer'} size="1vmin" />
			{/if}
			{craftLabel}
		</button>
	</div>
</div>

<style>
	.card {
		position: relative;
		width: calc(50% - 0.3vw);
		display: flex;
		flex-direction: column;
		background: rgba(255, 255, 255, 0.02);
		border: 1px solid rgba(255, 255, 255, 0.08);
		border-radius: var(--radius);
		box-shadow: 0 6px 16px rgba(0, 0, 0, 0.3), inset 0 1px 0 rgba(255, 255, 255, 0.04);
		overflow: hidden;
		transition: transform 120ms ease, border-color 120ms ease, box-shadow 120ms ease;
	}

	.card:hover {
		transform: translateY(-1px);
		border-color: rgba(255, 255, 255, 0.14);
		box-shadow: 0 10px 22px rgba(0, 0, 0, 0.35), inset 0 1px 0 rgba(255, 255, 255, 0.05);
	}

	.header {
		display: flex;
		align-items: center;
		gap: 0.7vw;
		padding: 0.9vh 0.8vw;
		border-bottom: 1px solid rgba(255, 255, 255, 0.06);
	}

	.icon {
		flex-shrink: 0;
		width: 5.4vh;
		height: 5.4vh;
		display: flex;
		align-items: center;
		justify-content: center;
		background: rgba(0, 0, 0, 0.25);
		border-radius: 3px;
		box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.4);
	}

	.icon img {
		max-width: 68%;
		max-height: 68%;
		object-fit: contain;
	}

	.title {
		display: flex;
		flex-direction: column;
		min-width: 0;
	}

	.name {
		font-size: 1.15vmin;
		font-weight: 600;
		color: var(--color-text);
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.yield {
		font-size: 1vmin;
		color: var(--color-text-muted);
		margin-top: 0.15vh;
	}

	.mats {
		flex: 1;
		min-height: 0;
		display: flex;
		flex-direction: column;
		padding: 0.3vh 0.8vw;
		max-height: 9.5vh;
		overflow-y: auto;
	}

	.mat-row {
		flex-shrink: 0;
		display: flex;
		align-items: center;
		gap: 0.45vw;
		padding: 0.4vh 0;
		border-bottom: 1px solid rgba(255, 255, 255, 0.05);
	}

	.mat-row:last-child {
		border-bottom: none;
	}

	.mat-icon {
		flex-shrink: 0;
		width: 3vh;
		height: 3vh;
		display: flex;
		align-items: center;
		justify-content: center;
		background: rgba(0, 0, 0, 0.3);
		border-radius: 4px;
	}

	.mat-icon img {
		max-width: 75%;
		max-height: 75%;
		object-fit: contain;
	}

	.mat-name {
		flex: 1;
		min-width: 0;
		font-size: 1.18vmin;
		color: var(--color-text);
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.mat-frac {
		flex-shrink: 0;
		font-size: 1.1vmin;
		font-weight: 600;
		color: var(--color-text-muted);
		font-variant-numeric: tabular-nums;
	}

	.mat-row.missing .mat-frac {
		color: var(--color-error);
	}

	.footer {
		flex-shrink: 0;
		display: flex;
		align-items: center;
		gap: 0.5vw;
		padding: 0.7vh 0.7vw;
		border-top: 1px solid rgba(255, 255, 255, 0.06);
		background: rgba(0, 0, 0, 0.15);
	}

	.stepper {
		flex-shrink: 0;
		display: flex;
		align-items: center;
		gap: 0.3vw;
		background: rgba(255, 255, 255, 0.05);
		border: 1px solid rgba(255, 255, 255, 0.08);
		border-radius: var(--radius);
		padding: 0.2vh 0.3vw;
	}

	.stepper button {
		background: transparent;
		border: none;
		color: var(--color-text-muted);
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		width: 2vh;
		height: 2vh;
		border-radius: 4px;
		transition: background 120ms ease, color 120ms ease;
	}

	.stepper button:hover:not(:disabled) {
		color: var(--color-primary-light);
		background: rgba(139, 92, 246, 0.16);
	}

	.stepper button:disabled {
		opacity: 0.3;
		pointer-events: none;
	}

	.stepper span {
		font-size: 1vmin;
		font-weight: 600;
		color: var(--color-text);
		min-width: 1.6vw;
		text-align: center;
	}

	.craft-btn {
		flex: 1;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.4vw;
		background: rgba(255, 255, 255, 0.05);
		border: 1px solid rgba(255, 255, 255, 0.08);
		border-radius: var(--radius);
		color: var(--color-text-muted);
		font-family: inherit;
		font-size: 0.95vmin;
		font-weight: 600;
		padding: 0.8vh 0.6vw;
		cursor: pointer;
		transition: background 120ms ease, border-color 120ms ease, color 120ms ease;
	}

	.craft-btn.ready {
		background: var(--color-primary-dark);
		border-color: var(--color-primary-dark);
		color: #ffffff;
	}

	.craft-btn.ready:hover {
		background: #3a2275;
		border-color: #3a2275;
	}

	.craft-btn:disabled {
		opacity: 0.55;
		pointer-events: none;
	}

	.spinner {
		width: 1.1vmin;
		height: 1.1vmin;
		border: 2px solid rgba(255, 255, 255, 0.25);
		border-top-color: var(--color-primary-light);
		border-radius: 50%;
		animation: spin 700ms linear infinite;
	}

	@keyframes spin {
		to {
			transform: rotate(360deg);
		}
	}

	.cooldown-overlay {
		position: absolute;
		inset: 0;
		background: rgba(8, 7, 12, 0.88);
		backdrop-filter: blur(1px);
		z-index: 10;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.6vw;
		color: var(--color-text-muted);
	}

	.inner {
		display: flex;
		flex-direction: column;
	}

	.cd-label {
		font-size: 0.85vmin;
		text-transform: uppercase;
		letter-spacing: 0.04em;
	}

	.time {
		font-size: 1.1vmin;
		font-weight: 600;
		color: var(--color-primary-light);
	}
</style>
