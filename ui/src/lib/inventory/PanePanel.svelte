<!-- One inventory pane: glass header (name, weight, quantity box, collapse chevron) above its slot grid -->
<script lang="ts">
	import type { Snippet } from 'svelte';
	import { dragState, getPane, itemDataFor, setDraggingAmount, togglePaneCollapsed, uiState } from '../store/inventory.svelte';
	import { trimKg } from '../util/weight';
	import chevronIcon from '../../assets/images/icon-settings.svg';
	import SlotGrid from './SlotGrid.svelte';
	import type { PaneId } from '../types';

	let { pane, fallbackName, fill = false, footer }: { pane: PaneId; fallbackName: string; fill?: boolean; footer?: Snippet } = $props();

	const paneState = $derived(getPane(pane));
	const collapsed = $derived(uiState.collapsed[pane]);
	const weight = $derived(paneState.inventory.reduce((sum, i) => (i ? sum + itemDataFor(i.Name).weight * i.Count : sum), 0));
	const capacity = $derived(paneState.capacityOverride || paneState.capacity);

	function onQuantityInput(e: Event) {
		setDraggingAmount(Number((e.target as HTMLInputElement).value) || 0);
	}
</script>

<section class="pane" class:fill class:collapsed class:player={pane === 'player'} data-panel>
	<header class="header">
		<div class="row">
			<span class="name">{paneState.name || fallbackName}</span>
			<span class="divider" aria-hidden="true"></span>
			<div class="controls">
				<span class="weight" class:over={weight > capacity}>{trimKg(weight)}/{trimKg(capacity)}kg</span>
				<input class="quantity" type="number" min="0" max="99999" placeholder="0" value={dragState.draggingAmount || ''} oninput={onQuantityInput} aria-label="Quantity to pick up" />
				<button type="button" class="collapse" onclick={() => togglePaneCollapsed(pane)} aria-label={collapsed ? 'Expand' : 'Collapse'} aria-expanded={!collapsed}>
					<img src={chevronIcon} alt="" width="18.75" height="15" />
				</button>
			</div>
		</div>
	</header>

	{#if !collapsed && paneState.loaded}
		<div class="body">
			<SlotGrid {pane} />
		</div>
		{@render footer?.()}
	{/if}
</section>

<style>
	.pane {
		display: flex;
		flex-direction: column;
		gap: calc(var(--u) * 12);
		/* every pane is exactly 5 slot columns wide, like inventoryconcept.html (5 x 78 + 4 x 9) */
		width: calc(var(--u) * 426);
		min-height: 0;
		pointer-events: auto;
	}

	.header {
		position: relative;
		flex-shrink: 0;
		width: calc(var(--u) * 690);
		max-width: 100%;
		height: calc(var(--u) * 61);
		padding: calc(var(--u) * 6) calc(var(--u) * 8);
		border: calc(var(--u) * 2) solid var(--glass-border);
		border-radius: calc(var(--u) * 12);
		background: var(--glass-bg-soft);
		box-shadow: inset 0 0 calc(var(--u) * 20) 0 rgba(255, 255, 255, 0.15), inset 0 0 calc(var(--u) * 10) 0 rgba(255, 255, 255, 0.1);
	}

	.row {
		position: relative;
		display: flex;
		align-items: center;
		justify-content: space-between;
		height: 100%;
		padding: calc(var(--u) * 4) calc(var(--u) * 8);
	}

	.name,
	.weight {
		font-size: calc(var(--u) * 16);
		font-weight: 600;
		color: var(--glass-text);
		white-space: nowrap;
	}

	.name {
		max-width: calc(var(--u) * 118);
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.weight {
		font-variant-numeric: tabular-nums;
	}

	.weight.over {
		color: var(--color-error);
	}

	/* decorative fading rule between the name and the controls */
	.divider {
		flex: 1;
		min-width: 0;
		margin: 0 calc(var(--u) * 12);
		height: calc(var(--u) * 2);
		background: linear-gradient(90deg, rgba(255, 255, 255, 0) 0%, rgba(255, 255, 255, 0.3) 25%, rgba(255, 255, 255, 0.5) 50%, rgba(255, 255, 255, 0.3) 75%, rgba(255, 255, 255, 0) 100%);
		pointer-events: none;
	}

	.controls {
		display: flex;
		align-items: center;
		gap: calc(var(--u) * 12);
	}

	.quantity,
	.collapse {
		height: calc(var(--u) * 34);
		background: var(--glass-bg);
		border: calc(var(--u) * 1) solid var(--glass-border-input);
		border-radius: calc(var(--u) * 4);
	}

	.quantity {
		width: calc(var(--u) * 74);
		padding: calc(var(--u) * 4) calc(var(--u) * 6);
		font-family: Arial, sans-serif;
		font-size: calc(var(--u) * 12);
		text-align: center;
		color: var(--glass-text);
		transition: border-color 120ms ease;
	}

	.quantity::placeholder {
		color: var(--glass-text);
	}

	.quantity:focus {
		outline: none;
		border-color: rgba(179, 157, 255, 0.6);
	}

	.collapse {
		width: calc(var(--u) * 34);
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 0;
		cursor: pointer;
		transition: border-color 120ms ease, background 120ms ease;
	}

	.collapse:hover {
		border-color: rgba(255, 255, 255, 0.4);
		background: rgba(50, 50, 50, 0.6);
	}

	.collapse img {
		width: calc(var(--u) * 18.75);
		height: calc(var(--u) * 15);
		transition: transform 180ms ease;
	}

	.collapsed .collapse img {
		transform: rotate(180deg);
	}

	.body {
		height: calc(var(--u) * 567.924);
		min-height: 0;
	}

	/* player pockets show exactly 4 rows (4 x 78 + 3 x 9); extra rows scroll */
	.pane.player .body {
		height: calc(var(--u) * 339);
	}

	/* the lower pane in a column takes whatever height is left, up to the same 567.9 cap */
	.fill {
		flex: 0 1 auto;
	}

	.fill .body {
		flex: 1 1 auto;
		display: flex;
		height: auto;
		max-height: calc(var(--u) * 567.924);
	}

	.fill .body > :global(.grid) {
		flex: 1 1 auto;
		height: auto;
		min-height: 0;
	}
</style>
