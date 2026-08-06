<!-- right-click quantity-split popover, arms a drag with the chosen count -->
<script lang="ts">
	import { pickUp } from '../store/inventory.svelte';
	import ActionButton from '../primitives/ActionButton.svelte';
	import type { InventorySlotItem, PaneId } from '../types';

	let { pane, item, onClose }: { pane: PaneId; item: InventorySlotItem; onClose: () => void } = $props();

	const max = $derived(Math.min(item.Count, 10000));
	// svelte-ignore state_referenced_locally
	let amount = $state(item.Count);

	function clamp(v: number): number {
		return Math.max(1, Math.min(Math.floor(v) || 1, max));
	}

	function onInput(e: Event) {
		amount = clamp(Number((e.target as HTMLInputElement).value));
	}

	function armDrag(count: number) {
		pickUp(pane, item, clamp(count));
		onClose();
	}

	function onBackdropContextMenu(e: MouseEvent) {
		e.preventDefault();
		onClose();
	}
</script>

<!-- Locks out the rest of the inventory until clicked; the click never reaches whatever's behind it -->
<div class="backdrop" onclick={onClose} oncontextmenu={onBackdropContextMenu} role="presentation"></div>

<div class="popover" onclick={(e) => e.stopPropagation()} oncontextmenu={(e) => e.stopPropagation()} role="presentation">
	<label class="field">
		<span class="label">Amount</span>
		<input type="number" min="1" {max} value={amount} oninput={onInput} />
		<span class="hint">Use scroll wheel +/-</span>
	</label>
	<div class="quick-row">
		<button type="button" class="quick" onclick={() => armDrag(1)}>Single</button>
		<button type="button" class="quick" onclick={() => armDrag(item.Count / 4)}>1/4</button>
		<button type="button" class="quick" onclick={() => armDrag(item.Count / 2)}>1/2</button>
		<button type="button" class="quick" onclick={() => armDrag(item.Count)}>Max</button>
	</div>
	<div class="move-row">
		<ActionButton label="Move" variant="primary" onclick={() => armDrag(amount)} />
	</div>
</div>

<style>
	.backdrop {
		position: fixed;
		inset: 0;
		background: transparent;
		cursor: default;
	}

	.popover {
		position: absolute;
		z-index: 1;
		width: 15vw;
		min-width: 200px;
		padding: 1.4vh 1vw;
		background: rgba(15, 17, 21, 0.97);
		border: var(--border-subtle);
		border-radius: 8px;
		box-shadow: 0 8px 24px rgba(0, 0, 0, 0.4);
	}

	.field {
		display: block;
	}

	.label {
		display: block;
		font-size: 0.85vmin;
		color: var(--color-text-muted);
		text-transform: uppercase;
		letter-spacing: 0.04em;
		margin-bottom: 0.4vh;
	}

	input[type='number'] {
		width: 100%;
		background: rgba(255, 255, 255, 0.06);
		border: var(--border-subtle);
		border-radius: 6px;
		color: var(--color-text);
		font-family: inherit;
		font-size: 1.2vmin;
		padding: 0.8vh 0.7vw;
	}

	.hint {
		display: block;
		margin-top: 0.4vh;
		font-size: 0.8vmin;
		color: var(--color-text-muted);
	}

	.quick-row {
		margin-top: 1.2vh;
		display: flex;
		gap: 0.4vw;
	}

	.quick {
		flex: 1;
		background: rgba(255, 255, 255, 0.08);
		border: 1px solid rgba(255, 255, 255, 0.05);
		border-radius: 6px;
		color: var(--color-text);
		font-family: inherit;
		font-size: 1vmin;
		padding: 0.8vh 0;
		cursor: pointer;
		transition: background 150ms ease, border-color 150ms ease, transform 150ms ease;
	}

	.quick:hover {
		background: rgba(255, 255, 255, 0.12);
		border-color: var(--color-primary);
		transform: translateY(-2px);
	}

	.move-row {
		margin-top: 1vh;
	}

	.move-row :global(.action) {
		width: 100%;
	}
</style>
