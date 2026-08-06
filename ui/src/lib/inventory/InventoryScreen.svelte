<!-- Main two-pane inventory screen: toolbar, player pane, and either secondary pane or CraftingScreen -->
<script lang="ts">
	import { fade } from 'svelte/transition';
	import { Nui } from '../nui';
	import { cancelDrag, cartCount, cartState, cartTotal, clearCart, dragState, isUsable, itemDataFor, playerPane, purchaseCart, secondaryPane, setDraggingAmount, uiState, useItemAt } from '../store/inventory.svelte';
	import { formatShopPrice } from '../../config';
	import Icon from '../Icon.svelte';
	import Modal from '../primitives/Modal.svelte';
	import SlotGrid from './SlotGrid.svelte';
	import AddToShopModal from './AddToShopModal.svelte';
	import CraftingScreen from '../crafting/CraftingScreen.svelte';
	import type { PaneState } from '../types';

	let showHelp = $state(false);

	function paneWeight(pane: PaneState): number {
		return pane.inventory.reduce((sum, i) => (i ? sum + itemDataFor(i.Name).weight * i.Count : sum), 0);
	}

	const playerWeight = $derived(paneWeight(playerPane));
	const secondaryWeight = $derived(paneWeight(secondaryPane));
	const secondaryCapacity = $derived(secondaryPane.capacityOverride || secondaryPane.capacity);
	const cartItemCount = $derived(cartCount());
	const cartPriceTotal = $derived(cartTotal());

	// Uses the currently-held item (mid-drag), letting you pick up then click USE instead of dropping
	const canUseHeld = $derived(dragState.origin?.pane === 'player' && dragState.held != null && isUsable('player', dragState.held));

	function onUseHeld() {
		if (!dragState.held) return;
		useItemAt('player', dragState.held);
		cancelDrag();
	}

	function onToggleMute() {
		void Nui.updateSettings({ muted: !uiState.settings.muted });
	}

	function onQuantityInput(e: Event) {
		setDraggingAmount(Number((e.target as HTMLInputElement).value) || 0);
	}
</script>

<div class="screen">
	<div class="toolbar">
		<input class="quantity" type="number" min="0" max="99999" placeholder="0" value={dragState.draggingAmount || ''} oninput={onQuantityInput} />
		<button type="button" class="use-btn" class:disabled={!canUseHeld} onclick={onUseHeld}>USE</button>
		<button type="button" class="close-btn" onclick={() => Nui.close()}>CLOSE</button>
		<div class="micro-actions">
			<button type="button" class="micro" title="Show UI Help" onclick={() => (showHelp = true)}>
				<Icon name="question" size="1.3vmin" />
			</button>
			<button type="button" class="micro" title={uiState.settings.muted ? 'Unmute UI Sounds' : 'Mute UI Sounds'} onclick={onToggleMute}>
				<Icon name={uiState.settings.muted ? 'volume-xmark' : 'volume-high'} size="1.3vmin" />
			</button>
		</div>
	</div>

	<div class="panes">
		<div class="pane">
			<div class="pane-header">{playerPane.name || 'Inventory'}</div>
			<div class="weight">
				<div class="weight-text">{playerWeight.toFixed(2)} / {playerPane.capacity.toFixed(2)}</div>
				<div class="weight-track"><div class="weight-fill" style:width={`${Math.min(100, Math.floor((playerWeight / playerPane.capacity) * 100))}%`}></div></div>
			</div>
			{#if playerPane.loaded}
				<SlotGrid pane="player" />
			{/if}
		</div>

		{#if uiState.mode === 'crafting'}
			<CraftingScreen />
		{:else if uiState.showSecondary}
			<div class="pane" transition:fade={{ duration: 200 }}>
				<div class="pane-header">{secondaryPane.name || 'Storage'}</div>
				<div class="weight">
					<div class="weight-text">{secondaryWeight.toFixed(2)} / {secondaryCapacity.toFixed(2)}</div>
					<div class="weight-track">
						<div class="weight-fill" style:width={`${Math.min(100, Math.floor((secondaryWeight / secondaryCapacity) * 100))}%`}></div>
					</div>
				</div>
				{#if secondaryPane.loaded}
					<SlotGrid pane="secondary" />
				{/if}
				{#if secondaryPane.shop && cartState.lines.length > 0}
					<div class="cart-bar" transition:fade={{ duration: 150 }}>
						<div class="cart-summary">
							<Icon name="dollar-sign" size="1.1vmin" />
							<span class="cart-count">{cartItemCount} item{cartItemCount === 1 ? '' : 's'}</span>
							<span class="cart-total">{formatShopPrice(cartPriceTotal)}</span>
						</div>
						<button type="button" class="cart-clear" onclick={clearCart} title="Clear cart">
							<Icon name="xmark" size="1vmin" />
						</button>
						<button type="button" class="cart-buy" onclick={purchaseCart}>Purchase</button>
					</div>
				{/if}
			</div>
		{/if}
	</div>
</div>

<Modal open={showHelp} title="Inventory Keys" closeLabel="Close" onClose={() => (showHelp = false)}>
	<p class="help-desc">Our inventory makes use of some hotkeys to facilitate quick operations. These keys can be found below:</p>
	<ul class="help-list">
		<li><b>Shift + Left Click: </b>Quick Transfer — move the stack to the other inventory (if possible)</li>
		<li><b>Left Click: </b>Pick up the amount typed in the quantity box above, or the full stack if none is set</li>
		<li><b>Ctrl + Right Click: </b>Pick up a single item from the stack</li>
		<li><b>Shift + Right Click: </b>Split Stack — opens a prompt to pick an exact amount</li>
		<li><b>Right Click: </b>Pick up half the stack</li>
		<li><b>Middle Mouse Button: </b>Use the selected item (if usable)</li>
		<li><b>Left Click Outside Panel (holding item): </b>Drop it on the ground</li>
		<li><b>Right Click Outside Panel (holding item): </b>Cancel</li>
	</ul>
</Modal>

<AddToShopModal />

<style>
	.screen {
		position: relative;
		display: flex;
		flex-direction: column;
		height: 100%;
		background: var(--color-bg-panel);
		border: var(--border-subtle);
		border-radius: var(--radius-lg);
		box-shadow: var(--shadow-panel);
		overflow: hidden;
	}

	.toolbar {
		position: relative;
		flex-shrink: 0;
		display: flex;
		align-items: center;
		gap: 0.6vw;
		padding: 1.2vh 1.4vw;
		background: rgba(255, 255, 255, 0.02);
		border-bottom: var(--border-subtle);
	}

	.quantity {
		width: 6vw;
		background: rgba(0, 0, 0, 0.25);
		border: var(--border-subtle);
		border-radius: var(--radius);
		color: var(--color-text);
		font-family: inherit;
		font-size: 1.3vmin;
		font-weight: 600;
		text-align: center;
		padding: 0.8vh 0.5vw;
		transition: border-color 120ms ease;
	}

	.quantity:focus {
		outline: none;
		border-color: rgba(139, 92, 246, 0.5);
	}

	.use-btn,
	.close-btn {
		border-radius: var(--radius);
		font-family: inherit;
		font-size: 1.05vmin;
		font-weight: 600;
		padding: 0.8vh 1.2vw;
		cursor: pointer;
		transition: background 120ms ease, border-color 120ms ease, color 120ms ease;
	}

	.use-btn {
		border: 1px solid var(--color-primary-dark);
		background: var(--color-primary-dark);
		color: #ffffff;
	}

	.use-btn:hover:not(.disabled) {
		background: #3a2275;
		border-color: #3a2275;
	}

	.use-btn.disabled {
		opacity: 0.35;
		pointer-events: none;
	}

	.close-btn {
		background: transparent;
		border: var(--border-subtle);
		color: var(--color-text-muted);
	}

	.close-btn:hover {
		border-color: rgba(217, 82, 90, 0.5);
		color: var(--color-error);
	}

	.micro-actions {
		margin-left: auto;
		display: flex;
		gap: 0.3vw;
	}

	.micro {
		background: transparent;
		border: none;
		color: var(--color-text-muted);
		cursor: pointer;
		padding: 0.7vh 0.6vw;
		display: flex;
		border-radius: var(--radius);
		transition: color 120ms ease, background 120ms ease;
	}

	.micro:hover {
		color: var(--color-primary-light);
		background: rgba(139, 92, 246, 0.12);
	}

	.panes {
		flex: 1;
		min-height: 0;
		display: flex;
		gap: 1px;
		background: rgba(255, 255, 255, 0.05);
	}

	.pane {
		flex: 0 0 auto;
		display: flex;
		flex-direction: column;
		background: rgba(10, 9, 14, 0.4);
		padding: 1.4vh 1.2vw;
	}

	.pane-header {
		flex-shrink: 0;
		font-family: var(--font-heading);
		font-size: 1.3vmin;
		font-weight: 600;
		letter-spacing: 0.02em;
		color: var(--color-text);
		margin-bottom: 0.8vh;
	}

	.weight {
		flex-shrink: 0;
		margin-bottom: 1vh;
	}

	.weight-text {
		font-size: 0.95vmin;
		color: var(--color-text-muted);
		margin-bottom: 0.35vh;
		font-variant-numeric: tabular-nums;
	}

	.weight-track {
		height: 5px;
		border-radius: 3px;
		background: rgba(255, 255, 255, 0.07);
		overflow: hidden;
	}

	.weight-fill {
		height: 100%;
		border-radius: 3px;
		background: linear-gradient(90deg, var(--color-primary-dark), var(--color-primary));
		transition: width 200ms ease;
	}

	.cart-bar {
		flex-shrink: 0;
		display: flex;
		align-items: center;
		gap: 0.8vw;
		margin-top: 1vh;
		padding: 0.9vh 1vw;
		background: rgba(255, 255, 255, 0.03);
		border: var(--border-subtle);
		border-radius: var(--radius-lg);
	}

	.cart-summary {
		flex: 1;
		min-width: 0;
		display: flex;
		align-items: center;
		gap: 0.5vw;
		color: var(--color-success);
	}

	.cart-count {
		font-size: 1vmin;
		color: var(--color-text-muted);
		white-space: nowrap;
	}

	.cart-total {
		margin-left: auto;
		font-size: 1.2vmin;
		font-weight: 700;
		color: var(--color-success);
		font-variant-numeric: tabular-nums;
	}

	.cart-clear {
		flex-shrink: 0;
		width: 2.6vh;
		height: 2.6vh;
		min-width: 24px;
		min-height: 24px;
		display: flex;
		align-items: center;
		justify-content: center;
		border: none;
		border-radius: var(--radius);
		background: rgba(255, 255, 255, 0.05);
		color: var(--color-text-muted);
		cursor: pointer;
		transition: background 120ms ease, color 120ms ease;
	}

	.cart-clear:hover {
		background: rgba(217, 82, 90, 0.16);
		color: var(--color-error);
	}

	.cart-buy {
		flex-shrink: 0;
		border: 1px solid var(--color-success);
		border-radius: var(--radius);
		padding: 0.8vh 1.4vw;
		font-family: inherit;
		font-size: 1.05vmin;
		font-weight: 600;
		color: #0f1c14;
		background: var(--color-success);
		cursor: pointer;
		transition: background 120ms ease, border-color 120ms ease;
	}

	.cart-buy:hover {
		background: #5bb85b;
		border-color: #5bb85b;
	}

	.help-desc {
		margin: 0 0 1vh;
		font-size: 1.1vmin;
		color: var(--color-text-muted);
		line-height: 1.5;
	}

	.help-list {
		margin: 0;
		padding-left: 1.2vw;
		font-size: 1.05vmin;
		color: var(--color-text-muted);
		line-height: 1.8;
	}

	.help-list b {
		color: var(--color-text);
	}
</style>
