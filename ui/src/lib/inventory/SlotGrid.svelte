<!-- One generic slot grid, reused for the player pane and every flavor of secondary pane -->
<script lang="ts">
	import { getPane } from '../store/inventory.svelte';
	import Slot from './Slot.svelte';
	import type { PaneId } from '../types';

	let { pane }: { pane: PaneId } = $props();

	const paneState = $derived(getPane(pane));

	// A shop lists its actual stock; everything else gets a fixed-size grid
	const slots = $derived(paneState.shop ? paneState.inventory.filter((i): i is NonNullable<typeof i> => !!i).map((i) => i.Slot) : Array.from({ length: paneState.size }, (_, i) => i + 1));
</script>

<div class="grid" class:shop-grid={paneState.shop}>
	{#each slots as slotNumber (slotNumber)}
		<Slot {pane} {slotNumber} item={paneState.inventory.find((i) => i?.Slot === slotNumber) ?? null} />
	{/each}
</div>

<style>
	.grid {
		display: grid;
		grid-template-columns: repeat(5, 4.6vw);
		align-content: flex-start;
		gap: 0.22vw;
		height: 100%;
		overflow-y: auto;
		padding: 0.4vh;
		scrollbar-width: none;
	}

	.grid::-webkit-scrollbar {
		display: none;
	}

	.grid.shop-grid {
		display: grid;
		grid-template-columns: repeat(3, 7.6vw);
		gap: 0.5vw;
		align-content: flex-start;
	}
</style>
