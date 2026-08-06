<!-- Always-on hotbar overlay; hidden while crafting or before the item catalog loads -->
<script lang="ts">
	import { fly } from 'svelte/transition';
	import { catalogState, hotbarState, uiState } from './store/inventory.svelte';
	import HotbarSlot from './HotbarSlot.svelte';

	const visible = $derived(uiState.mode !== 'crafting' && catalogState.itemsLoaded && Object.keys(catalogState.items).length > 0 && hotbarState.showHotbar);
</script>

{#if visible}
	<div class="hotbar" transition:fly={{ x: -40, duration: 220 }}>
		{#each Array(5) as _, i}
			<HotbarSlot slot={i + 1} item={hotbarState.items.find((s) => s?.Slot === i + 1) ?? null} />
		{/each}
		{#if hotbarState.equipped}
			<HotbarSlot item={hotbarState.equipped} equipped />
		{/if}
	</div>
{/if}

<style>
	.hotbar {
		position: absolute;
		top: 0;
		bottom: 0;
		left: 0;
		margin: auto;
		height: fit-content;
		display: flex;
		flex-direction: column;
		align-items: flex-start;
		justify-content: center;
		gap: 1vh;
		padding: 0 1.4vw;
		pointer-events: none;
		z-index: 5;
	}

	.hotbar :global(.slot.equipped) {
		margin-top: 0.6vh;
	}
</style>
