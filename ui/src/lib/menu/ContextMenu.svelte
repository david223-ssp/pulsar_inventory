<!-- Right-click item menu (ox_inventory InventoryContext): item header, a row of everyday action tiles,
     then the actions particular to the item. Keyboard: arrows move, Enter picks, Escape closes -->
<script lang="ts">
	import { tick } from 'svelte';
	import { quintOut } from 'svelte/easing';
	import { contextMenuState, closeContextMenu, isFavourite, toggleFavourite } from './menuState.svelte';
	import { placeAtPoint, MENU_MIDDLEWARE } from './floating';
	import TablerIcon from './TablerIcon.svelte';
	import type { TablerName } from './icons';
	import {
		BACKPACK_EQUIP_SLOT,
		canGive,
		canOpenContainer,
		dragState,
		dropHeldToGround,
		equipSlotAccepts,
		equipmentPane,
		findSlotItem,
		getPane,
		giveItemAt,
		placeItemAt,
		isUsable,
		itemDataFor,
		openContainerAt,
		pickUp,
		quickTransfer,
		uiState,
		useItemAt,
	} from '../store/inventory.svelte';
	import { getItemImage, getItemLabel } from '../util/itemImage';
	import { formatWeight } from '../util/weight';
	import { parseMetaData } from '../util/metadata';
	import { setClipboard } from '../util/clipboard';
	import { getRarityColor } from '../../config';
	import { Nui } from '../nui';

	const open = $derived(contextMenuState.coords != null);
	const pane = $derived(contextMenuState.pane);
	const item = $derived(contextMenuState.item);
	const itemData = $derived(item ? itemDataFor(item.Name) : null);
	const metadata = $derived(item ? parseMetaData(item.MetaData) : {});
	const serial = $derived(typeof metadata.SerialNumber === 'string' || typeof metadata.SerialNumber === 'number' ? String(metadata.SerialNumber) : null);

	const usable = $derived(!!pane && !!item && isUsable(pane, item));
	const favourite = $derived(!!item && isFavourite(item.Name));
	const canSplit = $derived(!!item && !!itemData?.isStackable && item.Count > 1);
	const canEquipBackpack = $derived(
		pane === 'player' && !!item && equipmentPane.loaded && equipSlotAccepts(BACKPACK_EQUIP_SLOT, item.Name) && !findSlotItem(equipmentPane, BACKPACK_EQUIP_SLOT),
	);
	// shift-click's destination, named in the row
	const transferTo = $derived.by(() => {
		if (!pane) return null;
		if (pane !== 'player') return getPane('player').name || 'Pockets';
		if (uiState.showSecondary && !getPane('secondary').shop) return getPane('secondary').name || 'Storage';
		if (uiState.showBackpack) return getPane('backpack').name || 'Backpack';
		return null;
	});
	const details = $derived(item && itemData ? [item.Count > 1 ? `×${item.Count}` : null, formatWeight(itemData.weight * item.Count) || null].filter(Boolean).join(' · ') : '');
	// container items that name their storage (containerLabel) get an entry that opens it, like ox's item buttons
	const openContainerLabel = $derived(pane && item && canOpenContainer(pane, item) ? (itemData?.containerLabel ?? null) : null);
	const hasList = $derived(!!openContainerLabel || canSplit || canEquipBackpack || !!transferTo || !!serial);

	let menuEl = $state<HTMLDivElement | undefined>(undefined);
	let pos = $state<{ x: number; y: number; origin: string } | null>(null);

	$effect(() => {
		const coords = contextMenuState.coords;
		if (!coords || !menuEl) return;
		pos = null;
		void placeAtPoint(menuEl, coords.x, coords.y, 'bottom-start', MENU_MIDDLEWARE).then((r) => {
			pos = { x: r.x, y: r.y, origin: r.placement.startsWith('top') ? 'bottom left' : 'top left' };
			void tick().then(() => buttons()[0]?.focus());
		});
	});

	function buttons(): HTMLButtonElement[] {
		return menuEl ? [...menuEl.querySelectorAll<HTMLButtonElement>('button:not(:disabled)')] : [];
	}

	function run(action: string) {
		if (!pane || !item) return;
		const p = pane;
		const it = item;
		closeContextMenu();
		switch (action) {
			case 'use':
				useItemAt(p, it);
				break;
			case 'open':
				openContainerAt(p, it);
				break;
			case 'give': {
				const typed = dragState.draggingAmount;
				giveItemAt(p, it, typed > 0 && typed < it.Count ? typed : it.Count);
				break;
			}
			case 'place': {
				const typed = dragState.draggingAmount;
				placeItemAt(p, it, typed > 0 && typed < it.Count ? typed : it.Count);
				break;
			}
			case 'drop': {
				const typed = dragState.draggingAmount;
				pickUp(p, it, typed > 0 && typed < it.Count ? typed : it.Count);
				dropHeldToGround();
				break;
			}
			case 'favourite':
				toggleFavourite(it.Name);
				break;
			case 'split':
				contextMenuState.splitRequest = { pane: p, slot: it.Slot };
				break;
			case 'equip':
			case 'transfer':
				quickTransfer(p, it);
				break;
			case 'copy':
				if (serial) setClipboard(serial);
				break;
		}
	}

	function onKeydown(e: KeyboardEvent) {
		if (!open) return;
		// the menu owns the keyboard while it's open (Escape must not close the whole inventory, Q/E must not switch tabs)
		e.stopPropagation();
		const list = buttons();
		const i = list.indexOf(document.activeElement as HTMLButtonElement);
		if (e.key === 'Escape' || e.key === 'Tab') {
			e.preventDefault();
			closeContextMenu();
		} else if (e.key === 'ArrowDown' || e.key === 'ArrowRight') {
			e.preventDefault();
			list[(i + 1) % list.length]?.focus();
		} else if (e.key === 'ArrowUp' || e.key === 'ArrowLeft') {
			e.preventDefault();
			list[(i - 1 + list.length) % list.length]?.focus();
		} else if (e.key === 'Home') {
			e.preventDefault();
			list[0]?.focus();
		} else if (e.key === 'End') {
			e.preventDefault();
			list[list.length - 1]?.focus();
		}
	}

	// ox's enter: opacity + scale(0.95) from the corner nearest the click, 160ms in / 100ms out
	function pop(_node: Element, { duration }: { duration: number }) {
		return {
			duration,
			easing: quintOut,
			css: (t: number) => `opacity: ${t}; transform: scale(${0.95 + 0.05 * t});`,
		};
	}

	const TILES: { action: string; label: string; icon: TablerName; tone?: 'danger' }[] = [
		{ action: 'use', label: 'Use', icon: 'play' },
		{ action: 'give', label: 'Give', icon: 'give' },
		{ action: 'place', label: 'Place', icon: 'place' },
		{ action: 'drop', label: 'Drop', icon: 'drop', tone: 'danger' },
		{ action: 'favourite', label: 'Favourite', icon: 'star' },
	];
</script>

<svelte:window onkeydowncapture={onKeydown} />

{#if open && item && itemData}
	<!-- anything outside the menu closes it, left or right click -->
	<div class="overlay" role="presentation" onmousedown={closeContextMenu} oncontextmenu={(e) => { e.preventDefault(); closeContextMenu(); }} onwheel={closeContextMenu}></div>
	<div
		bind:this={menuEl}
		class="context-menu-list"
		role="menu"
		tabindex="-1"
		style:left={pos ? `${pos.x}px` : '-9999px'}
		style:top={pos ? `${pos.y}px` : '-9999px'}
		style:transform-origin={pos?.origin ?? 'top left'}
		in:pop={{ duration: 160 }}
		out:pop={{ duration: 100 }}
		oncontextmenu={(e) => e.preventDefault()}
	>
		<div class="header" style:--rarity={getRarityColor(itemData.rarity)}>
			<div class="thumb">
				<img src={getItemImage(item, itemData)} alt="" />
			</div>
			<div class="heading">
				<span class="title">{getItemLabel(item, itemData)}</span>
				{#if details}<span class="details">{details}</span>{/if}
			</div>
		</div>

		<div class="tiles">
			{#each TILES as tile (tile.action)}
				{#if (tile.action !== 'use' || itemData.isUsable) && ((tile.action !== 'give' && tile.action !== 'place') || (!!pane && canGive(pane, item)))}
					<button
						type="button"
						role="menuitem"
						class="item tile"
						data-tone={tile.tone}
						data-on={tile.action === 'favourite' && favourite ? '' : undefined}
						title={tile.action === 'favourite' && favourite ? 'Remove favourite' : undefined}
						disabled={tile.action === 'use' && !usable}
						onmouseenter={(e) => (e.currentTarget as HTMLButtonElement).focus()}
						onclick={() => run(tile.action)}
					>
						<span class="icon"><TablerIcon name={tile.icon} /></span>
						<span class="label">{tile.label}</span>
					</button>
				{/if}
			{/each}
		</div>

		{#if hasList}
			<div class="divider"></div>
		{/if}

		{#if openContainerLabel}
			<button type="button" role="menuitem" class="item" onmouseenter={(e) => (e.currentTarget as HTMLButtonElement).focus()} onclick={() => run('open')}>
				<span class="icon"><TablerIcon name="dot" /></span><span class="label">{openContainerLabel}</span>
			</button>
		{/if}
		{#if canEquipBackpack}
			<button type="button" role="menuitem" class="item" onmouseenter={(e) => (e.currentTarget as HTMLButtonElement).focus()} onclick={() => run('equip')}>
				<span class="icon"><TablerIcon name="backpack" /></span><span class="label">Equip Backpack</span>
			</button>
		{/if}
		{#if transferTo}
			<button type="button" role="menuitem" class="item" onmouseenter={(e) => (e.currentTarget as HTMLButtonElement).focus()} onclick={() => run('transfer')}>
				<span class="icon"><TablerIcon name="send" /></span><span class="label">Move to {transferTo}</span>
			</button>
		{/if}
		{#if canSplit}
			<button type="button" role="menuitem" class="item" onmouseenter={(e) => (e.currentTarget as HTMLButtonElement).focus()} onclick={() => run('split')}>
				<span class="icon"><TablerIcon name="split" /></span><span class="label">Split Stack</span>
			</button>
		{/if}
		{#if serial}
			<button type="button" role="menuitem" class="item" onmouseenter={(e) => (e.currentTarget as HTMLButtonElement).focus()} onclick={() => { run('copy'); void Nui.frontEndSound('SELECT'); }}>
				<span class="icon"><TablerIcon name="copy" /></span><span class="label">Copy Serial</span>
			</button>
		{/if}
	</div>
{/if}

<style>
	.overlay {
		position: fixed;
		inset: 0;
		z-index: 290;
	}

	/* ox_inventory glass menu; --r = 1px of the ox design (1080p) */
	.context-menu-list {
		position: fixed;
		z-index: 300;
		width: calc(var(--r) * 244);
		display: flex;
		flex-direction: column;
		padding: calc(var(--r) * 6);
		border-radius: calc(var(--r) * 10);
		background: rgba(20, 23, 29, 0.96);
		box-shadow:
			inset 0 0 0 1px rgba(255, 255, 255, 0.1),
			0 calc(var(--r) * 18) calc(var(--r) * 40) rgba(0, 0, 0, 0.45);
		outline: none;
		font-family: var(--font-body);
		pointer-events: auto;
	}

	.header {
		display: flex;
		align-items: center;
		gap: calc(var(--r) * 10);
		padding: calc(var(--r) * 4) calc(var(--r) * 4) calc(var(--r) * 10);
		margin-bottom: calc(var(--r) * 6);
		border-bottom: 1px solid rgba(255, 255, 255, 0.06);
	}

	.thumb {
		position: relative;
		flex-shrink: 0;
		width: calc(var(--r) * 42);
		height: calc(var(--r) * 42);
		display: flex;
		align-items: center;
		justify-content: center;
		border-radius: calc(var(--r) * 6);
		background: rgba(226, 230, 240, 0.04);
		overflow: hidden;
	}

	/* rarity glow + rim behind the item art */
	.thumb::before,
	.thumb::after {
		content: '';
		position: absolute;
		inset: 0;
		border-radius: inherit;
		pointer-events: none;
	}

	.thumb::before {
		background: radial-gradient(circle at 50% 60%, var(--rarity), transparent 70%);
		opacity: 0.22;
	}

	.thumb::after {
		box-shadow: inset 0 0 0 1px var(--rarity);
		opacity: 0.28;
	}

	.thumb img {
		position: relative;
		width: 78%;
		height: 78%;
		object-fit: contain;
	}

	.heading {
		min-width: 0;
		display: flex;
		flex-direction: column;
		gap: calc(var(--r) * 4);
	}

	.title {
		font-size: calc(var(--r) * 14);
		font-weight: 700;
		line-height: 1.1;
		color: #ffffff;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.details {
		font-size: calc(var(--r) * 11);
		font-variant-numeric: tabular-nums;
		color: #71717a;
	}

	/* up to 5 tiles (Use, Give, Place, Drop, Favourite): rows of 3 so the labels keep their width */
	.tiles {
		display: grid;
		grid-template-columns: repeat(3, 1fr);
		gap: calc(var(--r) * 4);
	}

	.divider {
		height: 1px;
		margin: calc(var(--r) * 7) calc(var(--r) * 2) calc(var(--r) * 5);
		background: rgba(255, 255, 255, 0.06);
	}

	.item {
		display: flex;
		align-items: center;
		gap: calc(var(--r) * 10);
		padding: calc(var(--r) * 8) calc(var(--r) * 10);
		border: none;
		border-radius: calc(var(--r) * 6);
		background: transparent;
		outline: none;
		color: #d4d4d8;
		font: inherit;
		font-size: calc(var(--r) * 12);
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.14em;
		text-align: left;
		cursor: pointer;
	}

	.item:hover,
	.item:focus {
		color: #ffffff;
		background: linear-gradient(90deg, rgba(179, 157, 255, 0.16), transparent 80%);
		box-shadow: inset 3px 0 0 var(--color-primary-light);
	}

	.item:hover .icon,
	.item:focus .icon {
		color: var(--color-primary-light);
	}

	.item:disabled {
		opacity: 0.35;
		cursor: default;
	}

	.icon {
		flex-shrink: 0;
		display: flex;
		width: calc(var(--r) * 15);
		height: calc(var(--r) * 15);
		color: #71717a;
		transition: color 150ms ease-out;
	}

	.icon :global(svg) {
		width: 100%;
		height: 100%;
	}

	.label {
		flex: 1;
		min-width: 0;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.item.tile {
		flex-direction: column;
		justify-content: center;
		gap: calc(var(--r) * 7);
		padding: calc(var(--r) * 11) calc(var(--r) * 2) calc(var(--r) * 9);
		background: rgba(226, 230, 240, 0.04);
		box-shadow: inset 0 0 0 1px rgba(226, 230, 240, 0.06);
		font-size: calc(var(--r) * 10);
		letter-spacing: 0.12em;
		text-align: center;
	}

	.item.tile .icon {
		width: calc(var(--r) * 18);
		height: calc(var(--r) * 18);
	}

	.item.tile .label {
		flex: none;
		max-width: 100%;
	}

	.item.tile:hover,
	.item.tile:focus {
		background: rgba(179, 157, 255, 0.12);
		box-shadow: inset 0 0 0 1px rgba(179, 157, 255, 0.55);
	}

	.item.tile[data-tone='danger']:hover,
	.item.tile[data-tone='danger']:focus {
		color: #f87171;
		background: rgba(239, 68, 68, 0.12);
		box-shadow: inset 0 0 0 1px rgba(239, 68, 68, 0.55);
	}

	.item.tile[data-tone='danger']:hover .icon,
	.item.tile[data-tone='danger']:focus .icon {
		color: #f87171;
	}

	/* a set toggle (a favourite) keeps its icon lit and filled */
	.item.tile[data-on] .icon {
		color: var(--color-primary-light);
	}

	.item.tile[data-on] .icon :global(svg) {
		fill: currentColor;
	}
</style>
