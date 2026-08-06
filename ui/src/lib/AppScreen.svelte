<!-- Full-viewport backdrop + centered content box. Left-click drops held item on ground, right-click cancels -->
<script lang="ts">
	import type { Snippet } from 'svelte';
	import { catalogState, cancelDrag, dragState, dropHeldToGround, uiState } from './store/inventory.svelte';

	let { children }: { children: Snippet } = $props();

	function onBackdropClick() {
		if (dragState.origin) dropHeldToGround();
	}

	function onBackdropContextMenu(e: MouseEvent) {
		e.preventDefault();
		if (dragState.origin) cancelDrag();
	}
</script>

{#if catalogState.itemsLoaded && !uiState.hidden}
	<div class="backdrop" onclick={onBackdropClick} oncontextmenu={onBackdropContextMenu} onkeydown={() => {}} role="presentation">
		<div class="content" onclick={(e) => e.stopPropagation()} oncontextmenu={(e) => e.stopPropagation()} role="presentation">
			{@render children()}
		</div>
	</div>
{/if}

<style>
	.backdrop {
		position: absolute;
		inset: 0;
		background: rgba(0, 0, 0, 0.75);
		display: flex;
		align-items: center;
		justify-content: center;
		pointer-events: auto;
	}

	.content {
		width: fit-content;
		max-width: 90vw;
		height: 60vh;
		max-height: 720px;
	}
</style>
