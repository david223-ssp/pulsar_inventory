<!-- Player-shop "list this item for sale" dialog, opened when a drop lands on a shop pane in modify mode -->
<script lang="ts">
	import Modal from '../primitives/Modal.svelte';
	import { clearPendingShopAdd, itemDataFor, shopAddState, submitShopAdd } from '../store/inventory.svelte';
	import { getItemLabel } from '../util/itemImage';

	let price = $state(0);

	$effect(() => {
		if (shopAddState.pending) price = 0;
	});

	const itemData = $derived(shopAddState.pending ? itemDataFor(shopAddState.pending.item.Name) : null);
	const label = $derived(shopAddState.pending && itemData ? getItemLabel(shopAddState.pending.item, itemData) : '');

	function submit() {
		if (price <= 0) return;
		submitShopAdd(price);
	}
</script>

<Modal open={!!shopAddState.pending} title={`List ${label} For Sale`} submitLabel="List Item" onClose={clearPendingShopAdd} onSubmit={submit}>
	{#if shopAddState.pending}
		<label class="field">
			<span class="label">Quantity</span>
			<input type="number" value={shopAddState.pending.item.Count} disabled />
		</label>
		<label class="field">
			<span class="label">Price Per Unit</span>
			<input type="number" min="1" bind:value={price} required />
		</label>
	{/if}
</Modal>

<style>
	.field {
		display: block;
		margin-bottom: 1.2vh;
	}

	.label {
		display: block;
		font-size: 0.85vmin;
		color: var(--color-text-muted);
		text-transform: uppercase;
		letter-spacing: 0.04em;
		margin-bottom: 0.4vh;
	}

	input {
		width: 100%;
		background: rgba(255, 255, 255, 0.05);
		border: var(--border-subtle);
		border-radius: var(--radius);
		color: var(--color-text);
		font-family: inherit;
		font-size: 1.2vmin;
		padding: 0.8vh 0.7vw;
	}

	input:disabled {
		opacity: 0.5;
	}
</style>
