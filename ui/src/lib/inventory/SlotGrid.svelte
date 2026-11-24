<!-- One generic slot grid, reused for the player pane, the backpack pane and every flavor of secondary pane -->
<script lang="ts">
	import { getPane } from '../store/inventory.svelte';
	import { HOTBAR_SLOTS } from '../../config';
	import Slot from './Slot.svelte';
	import type { PaneId } from '../types';

	let { pane }: { pane: PaneId } = $props();

	const paneState = $derived(getPane(pane));

	// A shop lists its actual stock; everything else gets a fixed-size grid
	const slots = $derived(paneState.shop ? paneState.inventory.filter((i): i is NonNullable<typeof i> => !!i).map((i) => i.Slot) : Array.from({ length: paneState.size }, (_, i) => i + 1));
</script>

<div class="grid" class:shop-grid={paneState.shop}>
	{#each slots as slotNumber (slotNumber)}
		<Slot {pane} {slotNumber} item={paneState.inventory.find((i) => i?.Slot === slotNumber) ?? null} showNumber={pane === 'player' && slotNumber <= HOTBAR_SLOTS} />
	{/each}
</div>

<style>
	.grid {
		display: grid;
		/* square slots sized like inventoryconcept.html (~70px @1080p ≈ 78 design px, 8px gap ≈ 9) */
		grid-template-columns: repeat(auto-fill, calc(var(--u) * 78));
		grid-auto-rows: calc(var(--u) * 78);
		align-content: flex-start;
		gap: calc(var(--u) * 9);
		width: 100%;
		height: 100%;
		overflow-y: auto;
		scrollbar-width: none;
	}

	.grid::-webkit-scrollbar {
		display: none;
	}

	.grid.shop-grid {
		/* two storefront cards fill the 426-wide pane: 2 x 208.5 + 9 */
		grid-template-columns: repeat(2, calc(var(--u) * 208.5));
		grid-auto-rows: calc(var(--u) * 260);
		gap: calc(var(--u) * 6);
	}
</style>
