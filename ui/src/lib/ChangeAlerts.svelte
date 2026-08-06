<!-- pickup/loss/use toast feed -->
<script lang="ts">
	import { catalogState, changesState } from './store/inventory.svelte';
	import AlertToast from './AlertToast.svelte';

	const visible = $derived(catalogState.itemsLoaded && Object.keys(catalogState.items).length > 0);
	const alerts = $derived([...changesState.alerts].sort((a, b) => a.id - b.id).slice(0, 5));
</script>

{#if visible}
	<div class="stack">
		{#each alerts as alert (alert.id)}
			<AlertToast {alert} />
		{/each}
	</div>
{/if}

<style>
	.stack {
		position: absolute;
		right: 3vw;
		bottom: 3.5vh;
		width: fit-content;
		display: flex;
		flex-direction: row;
		align-items: flex-end;
		gap: 0.6vw;
		z-index: 5;
	}
</style>
