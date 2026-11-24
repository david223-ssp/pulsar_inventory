<!-- Full-canvas inventory layout (2146x1207 design canvas, scaled by --u), from the Figma "Health and injuries" frame
     (1920px frame, 1 Figma px = 1/1.0547 u, frame centre x960 = canvas centre x1073):
     tab pill on top; equipment + silhouette left (injuries under it on the Health tab); player + backpack centre;
     secondary pane, crafting or the "not available" card right -->
<script lang="ts">
	import { fade } from 'svelte/transition';
	import { cartCount, cartState, cartTotal, clearCart, purchaseCart, secondaryPane, uiState } from '../store/inventory.svelte';
	import { formatShopPrice } from '../../config';
	import Icon from '../Icon.svelte';
	import TabNav from '../TabNav.svelte';
	import PanePanel from './PanePanel.svelte';
	import AddToShopModal from './AddToShopModal.svelte';
	import EquipmentPanel from '../equipment/EquipmentPanel.svelte';
	import CraftingScreen from '../crafting/CraftingScreen.svelte';
	import HealthPanel from '../health/HealthPanel.svelte';

	const cartItemCount = $derived(cartCount());
	const cartPriceTotal = $derived(cartTotal());
</script>

<div class="tabs-slot">
	<TabNav />
</div>

<div class="equipment-slot">
	<EquipmentPanel />
</div>

{#if uiState.tab === 'health'}
	<div class="injuries-slot" transition:fade={{ duration: 200 }}>
		<HealthPanel />
	</div>
{/if}

<div class="center">
	<PanePanel pane="player" fallbackName="Inventory" />
	{#if uiState.showBackpack}
		<div class="backpack" transition:fade={{ duration: 200 }}>
			<PanePanel pane="backpack" fallbackName="Backpack" fill />
		</div>
	{/if}
</div>

{#if uiState.tab === 'experience'}
	<div class="right soon" data-panel transition:fade={{ duration: 150 }}>
		<span class="soon-title">EXPERIENCE</span>
		<span class="soon-text">Not available on this server yet.</span>
	</div>
{:else if uiState.tab === 'crafting'}
	<div class="right crafting" data-panel transition:fade={{ duration: 200 }}>
		<CraftingScreen />
	</div>
{:else if uiState.showSecondary}
	<div class="right" transition:fade={{ duration: 200 }}>
		<PanePanel pane="secondary" fallbackName="Storage">
			{#snippet footer()}
				{#if secondaryPane.shop && cartState.lines.length > 0}
					<div class="cart-bar" transition:fade={{ duration: 150 }}>
						<div class="cart-summary">
							<Icon name="dollar-sign" size="1.4vmin" />
							<span class="cart-count">{cartItemCount} item{cartItemCount === 1 ? '' : 's'}</span>
							<span class="cart-total">{formatShopPrice(cartPriceTotal)}</span>
						</div>
						<button type="button" class="cart-clear" onclick={clearCart} title="Clear cart">
							<Icon name="xmark" size="1.2vmin" />
						</button>
						<button type="button" class="cart-buy" onclick={purchaseCart}>Purchase</button>
					</div>
				{/if}
			{/snippet}
		</PanePanel>
	</div>
{/if}

<AddToShopModal />

<style>
	.tabs-slot,
	.equipment-slot,
	.injuries-slot,
	.center,
	.right {
		position: absolute;
	}

	/* Figma Navigation x599 y87 */
	.tabs-slot {
		left: calc(var(--u) * 730.7);
		top: calc(var(--u) * 82.5);
	}

	/* Figma equipment Container 132:3340 at x8 y145 */
	.equipment-slot {
		left: calc(var(--u) * 170.4);
		top: calc(var(--u) * 137.5);
	}

	/* Figma "INJURIES" label x27 y651 (rule x23), cards down to the bottom of the canvas */
	.injuries-slot {
		left: calc(var(--u) * 184.6);
		top: calc(var(--u) * 617.2);
		bottom: calc(var(--u) * 16);
	}

	/* Figma player/backpack Container x735 y202 */
	.center {
		left: calc(var(--u) * 859.7);
		top: calc(var(--u) * 191.5);
		bottom: calc(var(--u) * 16);
		display: flex;
		flex-direction: column;
		gap: calc(var(--u) * 19);
	}

	.backpack {
		display: flex;
		flex: 0 1 auto;
		min-height: 0;
	}

	/* Figma Drop Section x1304 y202 */
	.right {
		left: calc(var(--u) * 1399.2);
		top: calc(var(--u) * 191.5);
	}

	.right.crafting {
		width: calc(var(--u) * 690);
		height: calc(var(--u) * 640.92);
		border: calc(var(--u) * 2) solid var(--glass-border);
		border-radius: calc(var(--u) * 12);
		background: var(--glass-bg-soft);
		box-shadow: inset 0 0 calc(var(--u) * 20) 0 rgba(255, 255, 255, 0.15), inset 0 0 calc(var(--u) * 10) 0 rgba(255, 255, 255, 0.1);
		overflow: hidden;
		pointer-events: auto;
	}

	.soon {
		width: calc(var(--u) * 426);
		height: calc(var(--u) * 640.92);
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		gap: calc(var(--u) * 10);
		border: calc(var(--u) * 2) solid var(--glass-border);
		border-radius: calc(var(--u) * 12);
		background: var(--glass-bg-soft);
		box-shadow: inset 0 0 calc(var(--u) * 20) 0 rgba(255, 255, 255, 0.15), inset 0 0 calc(var(--u) * 10) 0 rgba(255, 255, 255, 0.1);
		pointer-events: auto;
	}

	.soon-title {
		font-family: var(--font-tabs);
		font-size: calc(var(--u) * 22);
		font-weight: 700;
		color: var(--color-primary-light);
	}

	.soon-text {
		font-size: calc(var(--u) * 15);
		color: var(--glass-text);
	}

	.cart-bar {
		flex-shrink: 0;
		display: flex;
		align-items: center;
		gap: calc(var(--u) * 12);
		width: 100%;
		padding: calc(var(--u) * 10) calc(var(--u) * 14);
		border: calc(var(--u) * 2) solid var(--glass-border);
		border-radius: calc(var(--u) * 12);
		background: var(--glass-bg);
	}

	.cart-summary {
		flex: 1;
		min-width: 0;
		display: flex;
		align-items: center;
		gap: calc(var(--u) * 8);
		color: var(--color-success);
	}

	.cart-count {
		font-size: calc(var(--u) * 14);
		color: var(--glass-text);
		white-space: nowrap;
	}

	.cart-total {
		margin-left: auto;
		font-size: calc(var(--u) * 16);
		font-weight: 700;
		color: var(--color-success);
		font-variant-numeric: tabular-nums;
	}

	.cart-clear {
		flex-shrink: 0;
		width: calc(var(--u) * 34);
		height: calc(var(--u) * 34);
		display: flex;
		align-items: center;
		justify-content: center;
		border: calc(var(--u) * 1) solid var(--glass-border-input);
		border-radius: calc(var(--u) * 4);
		background: var(--glass-bg);
		color: var(--glass-text);
		cursor: pointer;
		transition: background 120ms ease, color 120ms ease;
	}

	.cart-clear:hover {
		background: rgba(217, 82, 90, 0.16);
		color: var(--color-error);
	}

	.cart-buy {
		flex-shrink: 0;
		height: calc(var(--u) * 34);
		border: calc(var(--u) * 1) solid var(--color-success);
		border-radius: calc(var(--u) * 4);
		padding: 0 calc(var(--u) * 18);
		font-size: calc(var(--u) * 14);
		font-weight: 600;
		color: #0f1c14;
		background: var(--color-success);
		cursor: pointer;
		transition: background 120ms ease;
	}

	.cart-buy:hover {
		background: #5bb85b;
	}
</style>
