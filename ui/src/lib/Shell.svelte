<!-- Top-level shell: hotbar, alerts, main panel, hover/static tooltips -->
<script lang="ts">
	import { untrack } from 'svelte';
	import { fade } from 'svelte/transition';
	import { quintOut } from 'svelte/easing';
	import { pointer, placeAtPoint, TOOLTIP_MIDDLEWARE } from './menu/floating';
	import ContextMenu from './menu/ContextMenu.svelte';
	import { contextMenuState } from './menu/menuState.svelte';
	import type { HoverTooltipInfo } from './store/inventory.svelte';
	import { catalogState, hideSecondaryInventory, hoverTooltipState, itemDataFor, resetInventoryView, staticTooltipState, uiState } from './store/inventory.svelte';
	import Hotbar from './Hotbar.svelte';
	import ChangeAlerts from './ChangeAlerts.svelte';
	import AppScreen from './AppScreen.svelte';
	import InventoryScreen from './inventory/InventoryScreen.svelte';
	import HoverGhost from './inventory/HoverGhost.svelte';
	import ItemTooltip from './inventory/ItemTooltip.svelte';

	function onHideComplete() {
		hideSecondaryInventory();
		resetInventoryView();
	}

	const staticItemData = $derived(staticTooltipState.item ? itemDataFor(staticTooltipState.item.Name) : null);

	// ox_inventory behaviour: opens 500ms after the hover settles, then follows the cursor (right of it, flipping
	// and shifting to stay on screen); never while the context menu is open
	const OPEN_DELAY = 500;
	let shown = $state<HoverTooltipInfo | null>(null);
	let hoverTooltipEl = $state<HTMLDivElement | undefined>(undefined);
	let hoverTooltipPos = $state<{ top: number; left: number } | null>(null);

	$effect(() => {
		const info = hoverTooltipState.info;
		if (!info || contextMenuState.coords) {
			shown = null;
			return;
		}
		// same slot re-announcing itself (live data refresh): swap the content without restarting the delay
		const current = untrack(() => shown);
		if (current && current.item.Slot === info.item.Slot && current.pane === info.pane) {
			shown = info;
			return;
		}
		shown = null;
		const timer = setTimeout(() => (shown = info), OPEN_DELAY);
		return () => clearTimeout(timer);
	});

	function reposition() {
		if (!hoverTooltipEl) return;
		void placeAtPoint(hoverTooltipEl, pointer.x, pointer.y, 'right-start', TOOLTIP_MIDDLEWARE).then((r) => {
			hoverTooltipPos = { left: r.x, top: r.y };
		});
	}

	$effect(() => {
		if (!shown || !hoverTooltipEl) {
			hoverTooltipPos = null;
			return;
		}
		reposition();
		const onMove = () => reposition();
		window.addEventListener('mousemove', onMove, { passive: true });
		return () => window.removeEventListener('mousemove', onMove);
	});

	// ox's enter: 180ms rise (6px) + scale(0.97) + fade, 110ms out
	function rise(_node: Element, { duration }: { duration: number }) {
		return {
			duration,
			easing: quintOut,
			css: (t: number) => `opacity: ${t}; transform: translateY(${(1 - t) * 6}px) scale(${0.97 + 0.03 * t});`,
		};
	}
</script>

<Hotbar />
<ChangeAlerts />

{#if catalogState.itemsLoaded && staticTooltipState.item && staticItemData}
	<div class="static-tooltip">
		<ItemTooltip instance={staticTooltipState.item} itemData={staticItemData} />
	</div>
{/if}

{#if catalogState.itemsLoaded && shown}
	<div
		class="hover-tooltip"
		bind:this={hoverTooltipEl}
		style:top={hoverTooltipPos ? `${hoverTooltipPos.top}px` : '-9999px'}
		style:left={hoverTooltipPos ? `${hoverTooltipPos.left}px` : '-9999px'}
		style:visibility={hoverTooltipPos ? 'visible' : 'hidden'}
		in:rise={{ duration: 180 }}
		out:rise={{ duration: 110 }}
	>
		<ItemTooltip
			instance={shown.item}
			itemData={shown.itemData}
			pane={shown.pane}
			shop={shown.shop}
			free={shown.free}
			isEligible={shown.isEligible}
			isQualified={shown.isQualified}
		/>
	</div>
{/if}

{#if !uiState.hidden}
	<div class="fade-wrap" transition:fade={{ duration: 180 }} onoutroend={onHideComplete}>
		<AppScreen>
			<InventoryScreen />
		</AppScreen>
		<HoverGhost />
		<ContextMenu />
	</div>
{/if}

<style>
	.fade-wrap {
		position: absolute;
		inset: 0;
	}

	.static-tooltip {
		position: absolute;
		top: 3vh;
		left: 50%;
		transform: translateX(-50%);
		z-index: 50;
		pointer-events: none;
	}

	.hover-tooltip {
		position: fixed;
		z-index: 200;
		pointer-events: none;
		transform-origin: top left;
	}
</style>
