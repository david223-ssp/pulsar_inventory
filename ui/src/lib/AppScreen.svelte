<!-- Full-viewport click layer + the scaled 2146x1207 design canvas.
     Clicking anywhere that isn't a panel ([data-panel]) while holding an item drops it on the ground; right-click cancels -->
<script lang="ts">
	import type { Snippet } from 'svelte';
	import { catalogState, cancelDrag, dragState, dropHeldToGround, uiState } from './store/inventory.svelte';

	let { children }: { children: Snippet } = $props();

	function outsidePanels(e: MouseEvent): boolean {
		return !(e.target as Element | null)?.closest?.('[data-panel]');
	}

	function onBackdropClick(e: MouseEvent) {
		if (dragState.origin && outsidePanels(e)) dropHeldToGround();
	}

	function onBackdropContextMenu(e: MouseEvent) {
		e.preventDefault();
		if (dragState.origin && outsidePanels(e)) cancelDrag();
	}
</script>

{#if catalogState.itemsLoaded && !uiState.hidden}
	<div class="backdrop" onclick={onBackdropClick} oncontextmenu={onBackdropContextMenu} onkeydown={() => {}} role="presentation">
		<div class="canvas">
			{@render children()}
		</div>
	</div>
{/if}

<style>
	.backdrop {
		position: absolute;
		inset: 0;
		pointer-events: auto;
	}

	/* never transformed: a transform here would break the split popover's fixed-position backdrop */
	.canvas {
		position: absolute;
		inset: 0;
		margin: auto;
		width: calc(var(--u) * 2146);
		height: calc(var(--u) * 1207);
	}
</style>
