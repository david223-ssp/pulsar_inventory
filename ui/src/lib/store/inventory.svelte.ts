// Single domain store: item catalog, ui/mode, drag state, both panes, hotbar, crafting, toasts, tooltips

import { FALLBACK_ITEM, CHANGE_ALERT_DURATION_MS, CHANGE_ALERTS_MAX, HOTBAR_AUTOHIDE_MS } from '../../config';
import { Nui } from '../nui';
import { parseMetaData } from '../util/metadata';
import dragSfxUrl from '../../assets/drag.mp3';
import type { ChangeAlert, Cooldowns, InventorySettings, InventorySlotItem, ItemDefinition, MoveSlotPayload, PaneId, PaneState, Recipe } from '../types';

// Plays on every completed drag and quick-transfer
const dragSfx = new Audio(dragSfxUrl);
dragSfx.volume = 0.25;
function playDragSfx(): void {
	if (uiState.settings.muted) return;
	dragSfx.currentTime = 0;
	void dragSfx.play();
}

function emptyPane(): PaneState {
	return {
		loaded: false,
		size: 0,
		invType: 1,
		name: '',
		inventory: [],
		disabled: {},
		owner: 0,
		capacity: 100,
	};
}

// Panes are `$state` objects mutated in place, never reassigned
function replacePane(pane: PaneState, next: Partial<PaneState>, preserveDisabled: boolean): void {
	const disabled = preserveDisabled ? pane.disabled : {};
	Object.assign(pane, emptyPane(), next, { disabled });
}

export const catalogState = $state({
	items: {} as Record<string, ItemDefinition>,
	itemsLoaded: false,
});

export const uiState = $state({
	hidden: true,
	mode: 'inventory' as 'inventory' | 'crafting',
	settings: { muted: false, useBank: false } as InventorySettings,
	inUse: false,
	showSecondary: false,
});

export const playerPane = $state<PaneState>(emptyPane());
export const secondaryPane = $state<PaneState>(emptyPane());

export const hotbarState = $state({
	showHotbar: false,
	items: [] as (InventorySlotItem | null)[],
	equipped: null as InventorySlotItem | null,
});

// Re-arms on every HOTBAR_SHOW so rapid pickups keep the full 5s from the last one
let hotbarHideTimer: ReturnType<typeof setTimeout> | undefined;
function armHotbarAutoHide(): void {
	clearTimeout(hotbarHideTimer);
	hotbarHideTimer = setTimeout(() => {
		hotbarState.showHotbar = false;
	}, HOTBAR_AUTOHIDE_MS);
}

export const craftingState = $state({
	bench: 'none',
	recipes: [] as Recipe[],
	cooldowns: {} as Cooldowns,
	schematics: {} as Record<string, { result: { name: string; count: number } }>,
});

export const changesState = $state({ alerts: [] as ChangeAlert[] });

export const staticTooltipState = $state({ item: null as InventorySlotItem | null });

// ---- Hover tooltip ----
// Rendered at the Shell level, fixed-position, so it escapes SlotGrid's scroll clipping
export interface HoverTooltipInfo {
	item: InventorySlotItem;
	itemData: ItemDefinition;
	shop: boolean;
	free: boolean;
	isEligible: boolean;
	isQualified: boolean;
	rect: { top: number; bottom: number; left: number; right: number; width: number };
}

export const hoverTooltipState = $state({ info: null as HoverTooltipInfo | null });

// ---- Drag-in-progress state ----
export interface DragOrigin {
	pane: PaneId;
	owner: string | number;
	invType: number;
	slot: number;
	item: InventorySlotItem;
	vehClass?: number;
	vehModel?: number;
	slotOverride?: number;
	capacityOverride?: number;
}

export const dragState = $state({
	origin: null as DragOrigin | null,
	held: null as InventorySlotItem | null,
	draggingAmount: 0,
});

export function getPane(id: PaneId): PaneState {
	return id === 'player' ? playerPane : secondaryPane;
}

function findSlotItem(pane: PaneState, slot: number): InventorySlotItem | null {
	return pane.inventory.find((i) => i?.Slot === slot) ?? null;
}

function calcPaneWeight(pane: PaneState): number {
	return pane.inventory.reduce((sum, i) => (i ? sum + (catalogState.items[i.Name]?.weight ?? 0) * i.Count : sum), 0);
}

export function itemDataFor(name: string | undefined): ItemDefinition {
	if (!name) return FALLBACK_ITEM as ItemDefinition;
	return catalogState.items[name] ?? (FALLBACK_ITEM as ItemDefinition);
}

// ---- Inbound message handling ----

export function handleInventoryMessage(type: string, data: unknown): void {
	const d = (data ?? {}) as Record<string, any>;
	switch (type) {
		case 'ITEMS_UNLOADED':
		case 'RESET_ITEMS':
			catalogState.items = {};
			catalogState.itemsLoaded = false;
			break;
		case 'SET_ITEMS':
			catalogState.items = d.items ?? {};
			break;
		case 'ADD_ITEM':
			catalogState.items = { ...catalogState.items, [d.id]: d.item };
			break;
		case 'ITEMS_LOADED':
			catalogState.itemsLoaded = true;
			break;

		case 'APP_SHOW':
			uiState.hidden = false;
			break;
		case 'APP_HIDE':
			uiState.hidden = true;
			dragState.origin = null;
			dragState.held = null;
			cartState.lines = [];
			hoverTooltipState.info = null;
			break;
		case 'SET_MODE':
			uiState.mode = d.mode;
			break;
		case 'UPDATE_SETTINGS':
			uiState.settings = { ...uiState.settings, ...d.settings };
			break;
		case 'USE_IN_PROGRESS':
			uiState.inUse = !!d.state;
			break;

		case 'SHOW_SECONDARY_INVENTORY':
			uiState.showSecondary = true;
			break;

		case 'SET_PLAYER_INVENTORY':
			replacePane(playerPane, { ...(d as PaneState), invType: 1 }, true);
			break;
		case 'SET_PLAYER_SLOT':
			playerPane.disabled = { ...playerPane.disabled, [d.slot]: false };
			break;
		case 'SLOT_NOT_USED':
			playerPane.disabled = { ...playerPane.disabled, [d.originSlot]: false };
			break;

		case 'SET_SECONDARY_INVENTORY': {
			const samePane = secondaryPane.owner === d.owner && secondaryPane.invType === d.invType;
			if (!samePane) cartState.lines = [];
			replacePane(secondaryPane, d as PaneState, samePane);
			break;
		}
		case 'SET_SECONDARY_SLOT':
			secondaryPane.disabled = { ...secondaryPane.disabled, [d.slot]: false };
			break;

		// resync after a failed shop purchase, merges onto current pane state and keeps `disabled`
		case 'SET_INVENTORIES':
			if (d.player) Object.assign(playerPane, d.player, { invType: 1, disabled: playerPane.disabled });
			if (d.secondary) Object.assign(secondaryPane, d.secondary, { disabled: secondaryPane.disabled });
			break;

		case 'HOTBAR_SHOW':
			hotbarState.showHotbar = true;
			hotbarState.items = d.items ?? [];
			armHotbarAutoHide();
			break;
		case 'HOTBAR_HIDE':
			hotbarState.showHotbar = false;
			break;
		case 'SET_EQUIPPED':
			hotbarState.equipped = d.item ?? null;
			break;

		case 'SET_BENCH':
			uiState.mode = 'crafting';
			craftingState.bench = d.bench;
			craftingState.cooldowns = d.cooldowns ?? {};
			craftingState.recipes = d.recipes ?? [];
			break;
		case 'SET_SCHEMS':
			craftingState.schematics = d ?? {};
			break;

		case 'USE_ITEM_PLAYER':
			playerPane.disabled = { ...playerPane.disabled, [d.originSlot]: true };
			break;

		case 'OPEN_STATIC_TOOLTIP':
			staticTooltipState.item = d.item ?? null;
			break;
		case 'CLOSE_STATIC_TOOLTIP':
			staticTooltipState.item = null;
			break;

		case 'ADD_ALERT':
			pushChangeAlert(d.alert as ChangeAlert);
			break;
	}
}

function pushChangeAlert(alert: ChangeAlert): void {
	changesState.alerts = [...changesState.alerts, alert].slice(-CHANGE_ALERTS_MAX);
	setTimeout(() => dismissChangeAlert(alert.id), CHANGE_ALERT_DURATION_MS);
}

export function dismissChangeAlert(id: number): void {
	changesState.alerts = changesState.alerts.filter((a) => a.id !== id);
}

// Called from Shell.svelte once the hide fade-out transition finishes
export function resetInventoryView(): void {
	replacePane(playerPane, {}, true);
	replacePane(secondaryPane, {}, true);
}

export function hideSecondaryInventory(): void {
	uiState.showSecondary = false;
	replacePane(secondaryPane, {}, false);
	cartState.lines = [];
}

// ---- Drag lifecycle ----

export function pickUp(pane: PaneId, item: InventorySlotItem, count: number = item.Count): void {
	const p = getPane(pane);
	dragState.origin = {
		pane,
		owner: p.owner,
		invType: p.invType,
		slot: item.Slot,
		item,
		vehClass: p.class,
		vehModel: p.model,
		slotOverride: p.slotOverride,
		capacityOverride: p.capacityOverride,
	};
	dragState.held = { ...item, Count: count };
}

export function cancelDrag(): void {
	dragState.origin = null;
	dragState.held = null;
}

export function dropHeldToGround(): void {
	const origin = dragState.origin;
	const held = dragState.held;
	if (!origin || !held) return;

	const pane = getPane(origin.pane);
	if (!pane.shop) {
		pane.inventory = pane.inventory
			.map((i) => (i?.Slot === origin.slot ? { ...i, Count: i.Count - held.Count } : i))
			.filter((i) => i?.Slot !== origin.slot || i.Count > 0);
	}

	playDragSfx();
	void Nui.dropToGround({
		ownerFrom: origin.owner,
		invTypeFrom: origin.invType,
		slotFrom: origin.slot,
		name: origin.item.Name,
		count: held.Count,
		vehClassFrom: origin.vehClass,
		vehModelFrom: origin.vehModel,
		slotOverrideFrom: origin.slotOverride,
		capacityOverrideFrom: origin.capacityOverride,
	});

	cancelDrag();
}

export function setDraggingAmount(amount: number): void {
	dragState.draggingAmount = Math.max(0, amount);
}

function isDestBlocked(destPaneId: PaneId, destItem: InventorySlotItem | null): boolean {
	if (!destItem) return false;
	const destPane = getPane(destPaneId);
	const destItemData = itemDataFor(destItem.Name);
	const destMeta = parseMetaData(destItem.MetaData);

	const weaponDisabled = !!destPane.shop && !!destItemData.requiresLicense && destItemData.type === 2 && !playerPane.isWeaponEligble;
	const qualiDisabled = !!destPane.shop && !!destItemData.qualification && !(playerPane.qualifications ?? []).includes(destItemData.qualification);
	const openContainer = destItemData.type === 10 && secondaryPane.owner === `container:${destMeta.Container}`;

	return weaponDisabled || qualiDisabled || openContainer;
}

type MoveKind = 'merge' | 'split' | 'swap' | 'move';

// A pending "Add to Shop" listing request, set when a drop lands on a player-shop-in-modify-mode
export interface PendingShopAdd {
	pane: PaneId;
	slotFrom: number;
	slotTo: number;
	item: InventorySlotItem;
}

export const shopAddState = $state({ pending: null as PendingShopAdd | null });

// ---- Shop cart ----
// A "how many of this am I buying" line per shop slot; purchasing still goes through pickUp()+attemptDrop()
export interface CartLine {
	slot: number;
	name: string;
	unitPrice: number;
	qty: number;
	stock: number;
}

export const cartState = $state({ lines: [] as CartLine[] });

export function cartCount(): number {
	return cartState.lines.reduce((sum, l) => sum + l.qty, 0);
}

export function cartTotal(): number {
	return cartState.lines.reduce((sum, l) => sum + l.qty * l.unitPrice, 0);
}

export function cartQtyFor(slot: number): number {
	return cartState.lines.find((l) => l.slot === slot)?.qty ?? 0;
}

export function setCartQty(item: InventorySlotItem, unitPrice: number, qty: number): void {
	const clamped = Math.max(0, Math.min(qty, item.Count));
	if (clamped <= 0) {
		cartState.lines = cartState.lines.filter((l) => l.slot !== item.Slot);
		return;
	}
	const existing = cartState.lines.find((l) => l.slot === item.Slot);
	if (existing) {
		cartState.lines = cartState.lines.map((l) => (l.slot === item.Slot ? { ...l, qty: clamped, stock: item.Count } : l));
	} else {
		cartState.lines = [...cartState.lines, { slot: item.Slot, name: item.Name, unitPrice, qty: clamped, stock: item.Count }];
	}
}

export function clearCart(): void {
	cartState.lines = [];
}

// Checks out every cart line by replaying the same pickUp+attemptDrop pair a manual drag-to-buy performs
export function purchaseCart(): void {
	if (!secondaryPane.shop || cartState.lines.length === 0) return;

	for (const line of cartState.lines) {
		const item = findSlotItem(secondaryPane, line.slot);
		const qty = item ? Math.min(line.qty, item.Count) : 0;
		if (!item || qty <= 0) continue;

		const itemDef = itemDataFor(item.Name);
		const stackTarget = playerPane.inventory.find((i) => i && i.Name === item.Name && !!itemDef.isStackable && i.Count + qty <= itemDef.isStackable);
		let destSlot: number | null = stackTarget?.Slot ?? null;
		if (destSlot == null) {
			for (let i = 1; i <= playerPane.size; i++) {
				if (!playerPane.inventory.some((s) => s?.Slot === i)) {
					destSlot = i;
					break;
				}
			}
		}

		if (destSlot == null) {
			void Nui.frontEndSound('DISABLED');
			continue;
		}

		pickUp('secondary', item, qty);
		attemptDrop('player', destSlot);
	}

	clearCart();
}

// A pending shop listing is only offered for a player shop the viewer can currently edit, with room left
function canAddToShop(originPaneId: PaneId): boolean {
	return !!secondaryPane.playerShop && !!secondaryPane.modifyShop && !uiState.inUse && originPaneId === 'player' && secondaryPane.inventory.length < 50;
}

// The single move/merge/swap/split resolver; handles same-pane and cross-pane drops identically
export function attemptDrop(destPaneId: PaneId, destSlot: number): void {
	const origin = dragState.origin;
	const held = dragState.held;
	if (!origin || !held) return;

	const destPane = getPane(destPaneId);
	const destItem = findSlotItem(destPane, destSlot);
	const destItemData = destItem ? itemDataFor(destItem.Name) : null;

	// dropping onto a slot with an unknown item definition, no-op and keep holding
	if (destItem && (!destItemData || destItemData.invalid)) return;

	// dropping back onto the exact slot it came from, cancel instead of moving
	if (origin.pane === destPaneId && origin.slot === destSlot) {
		cancelDrag();
		return;
	}

	if (isDestBlocked(destPaneId, destItem)) {
		void Nui.frontEndSound('DISABLED');
		return;
	}

	if (destPaneId === 'secondary' && destPane.shop) {
		void Nui.frontEndSound('DISABLED');
		return;
	}

	if (destPaneId === 'secondary' && destPane.playerShop) {
		if (canAddToShop(origin.pane)) {
			shopAddState.pending = { pane: origin.pane, slotFrom: origin.slot, slotTo: destSlot, item: held };
		} else {
			void Nui.frontEndSound('DISABLED');
		}
		cancelDrag();
		return;
	}

	const heldItemData = itemDataFor(held.Name);
	const heldWeight = (heldItemData.weight ?? 0) * held.Count;

	if (origin.pane !== destPaneId) {
		const destWeight = calcPaneWeight(destPane) + heldWeight;
		if (destWeight > destPane.capacity) {
			void Nui.frontEndSound('DISABLED');
			return;
		}
	}

	// buying onto an already-occupied slot with a different item is blocked
	if (destPaneId === 'player' && origin.pane === 'secondary' && secondaryPane.shop && destItem && destItem.Name !== origin.item.Name) {
		void Nui.frontEndSound('DISABLED');
		return;
	}

	const isSplitPickup = origin.item.Count !== held.Count;
	const maxStack = itemDataFor(origin.item.Name).isStackable || Infinity;

	let kind: MoveKind;
	if (destItem && destItem.Name === origin.item.Name && destItem.Count + held.Count <= maxStack) {
		kind = isSplitPickup ? 'split' : 'merge';
	} else if (destItem) {
		kind = 'swap';
	} else {
		kind = isSplitPickup ? 'split' : 'move';
	}

	const payload: MoveSlotPayload = {
		ownerFrom: origin.owner,
		ownerTo: destPane.owner,
		slotFrom: origin.slot,
		slotTo: destSlot,
		name: origin.item.Name,
		countFrom: origin.item.Count,
		countTo: held.Count,
		invTypeFrom: origin.invType,
		invTypeTo: destPane.invType,
		vehClassFrom: origin.vehClass,
		vehClassTo: destPane.class,
		vehModelFrom: origin.vehModel,
		vehModelTo: destPane.model,
		slotOverrideFrom: origin.slotOverride,
		slotOverrideTo: destPane.slotOverride,
		capacityOverrideFrom: origin.capacityOverride,
		capacityOverrideTo: destPane.capacityOverride,
	};

	playDragSfx();
	applyOptimisticMove(origin.pane, destPaneId, origin.slot, destSlot, held, kind, !!getPane(origin.pane).shop);

	if (kind === 'merge') void Nui.mergeSlot(payload);
	else if (kind === 'swap') void Nui.swapSlot(payload);
	else void Nui.moveSlot({ ...payload, isSplit: kind === 'split' });

	cancelDrag();
}

function applyOptimisticMove(originId: PaneId, destId: PaneId, originSlot: number, destSlot: number, movedItem: InventorySlotItem, kind: MoveKind, originIsShop: boolean): void {
	const origin = getPane(originId);
	const dest = getPane(destId);

	origin.disabled = { ...origin.disabled, [originSlot]: true };
	dest.disabled = { ...dest.disabled, [destSlot]: true };

	// Fakes the "verified" response in dev, since there's no real server round-trip to flip `disabled` off
	if (import.meta.env.DEV) {
		setTimeout(() => {
			origin.disabled = { ...origin.disabled, [originSlot]: false };
			dest.disabled = { ...dest.disabled, [destSlot]: false };
		}, 650);
	}

	if (kind === 'swap') {
		const originFull = findSlotItem(origin, originSlot);
		const destFull = findSlotItem(dest, destSlot);
		origin.inventory = origin.inventory.filter((i) => i?.Slot !== originSlot);
		dest.inventory = dest.inventory.filter((i) => i?.Slot !== destSlot);
		if (destFull) origin.inventory = [...origin.inventory, { ...destFull, Slot: originSlot }];
		if (originFull) dest.inventory = [...dest.inventory, { ...originFull, Slot: destSlot }];
		return;
	}

	if (kind === 'merge') {
		if (!originIsShop) origin.inventory = origin.inventory.filter((i) => i?.Slot !== originSlot);
		dest.inventory = dest.inventory.map((i) => (i?.Slot === destSlot ? { ...i, Count: i.Count + movedItem.Count } : i));
		return;
	}

	if (kind === 'split') {
		if (!originIsShop) origin.inventory = origin.inventory.map((i) => (i?.Slot === originSlot ? { ...i, Count: i.Count - movedItem.Count } : i));
		const destExists = dest.inventory.some((i) => i?.Slot === destSlot);
		dest.inventory = destExists ? dest.inventory.map((i) => (i?.Slot === destSlot ? { ...i, Count: i.Count + movedItem.Count } : i)) : [...dest.inventory, { ...movedItem, Slot: destSlot }];
		return;
	}

	// move
	if (!originIsShop) origin.inventory = origin.inventory.filter((i) => i?.Slot !== originSlot);
	dest.inventory = [...dest.inventory, { ...movedItem, Slot: destSlot, CreateDate: originIsShop ? Date.now() / 1000 : movedItem.CreateDate }];
}

// Shift-click quick-transfer: finds the first matching stack (or empty slot) in the other pane and moves instantly
export function quickTransfer(originPaneId: PaneId, item: InventorySlotItem): void {
	const destPaneId: PaneId = originPaneId === 'player' ? 'secondary' : 'player';
	const destPane = getPane(destPaneId);
	if (!uiState.showSecondary) return;
	if (destPaneId === 'secondary' && destPane.shop) {
		void Nui.frontEndSound('DISABLED');
		return;
	}

	const itemDef = itemDataFor(item.Name);
	const sorted = destPane.inventory.filter((i): i is InventorySlotItem => !!i).sort((a, b) => a.Slot - b.Slot);
	const stackTarget = sorted.find((s) => s.Name === item.Name && !!itemDef.isStackable && item.Count + s.Count <= itemDef.isStackable);

	let destSlot: number | null = stackTarget?.Slot ?? null;
	if (destSlot == null) {
		for (let i = 1; i <= destPane.size; i++) {
			if (!destPane.inventory.some((s) => s?.Slot === i)) {
				destSlot = i;
				break;
			}
		}
	}

	if (destSlot == null) {
		void Nui.frontEndSound('DISABLED');
		return;
	}

	playDragSfx();
	pickUp(originPaneId, item, item.Count);
	attemptDrop(destPaneId, destSlot);
}

export function clearPendingShopAdd(): void {
	shopAddState.pending = null;
}

export function submitShopAdd(price: number): void {
	const pending = shopAddState.pending;
	if (!pending) return;
	const pane = getPane(pending.pane);
	void Nui.addToShop({
		ownerFrom: pane.owner,
		invTypeFrom: pane.invType,
		slotFrom: pending.slotFrom,
		ownerTo: secondaryPane.owner,
		invTypeTo: secondaryPane.invType,
		slotTo: pending.slotTo,
		price,
		quantity: pending.item.Count,
	});
	void Nui.frontEndSound('SHOP_ADD');
	shopAddState.pending = null;
}

export function isUsable(pane: PaneId, item: InventorySlotItem | null | undefined): boolean {
	if (uiState.mode !== 'inventory' || !item) return false;
	const itemData = itemDataFor(item.Name);
	if (itemData.invalid) return false;
	if (uiState.inUse) return false;
	if (getPane(pane).owner !== playerPane.owner) return false;
	if (!itemData.isUsable) return false;
	if (itemData.durability && item.CreateDate + itemData.durability <= Date.now() / 1000) return false;
	return true;
}

export function useItemAt(pane: PaneId, item: InventorySlotItem): void {
	if (!isUsable(pane, item)) {
		void Nui.frontEndSound('DISABLED');
		return;
	}
	const p = getPane(pane);
	void Nui.useItem(p.owner, item.Slot, p.invType);
	p.disabled = { ...p.disabled, [item.Slot]: true };
}

// ---- Crafting ----

// Applies a successful Crafting:Craft response: fresh player inventory + refreshed cooldowns
export function applyCraftResult(inventory: InventorySlotItem[], cooldowns: Cooldowns): void {
	playerPane.inventory = inventory;
	craftingState.cooldowns = cooldowns;
}
