// Right-click item menu (ox_inventory's InventoryContext): opened at the click point for one slot
import type { InventorySlotItem, PaneId } from '../types';

export const contextMenuState = $state({
	coords: null as { x: number; y: number } | null,
	pane: null as PaneId | null,
	item: null as InventorySlotItem | null,
	/** set by the menu's "Split" action; the matching Slot opens its split popover and clears it */
	splitRequest: null as { pane: PaneId; slot: number } | null,
});

export function openContextMenu(pane: PaneId, item: InventorySlotItem, x: number, y: number): void {
	contextMenuState.pane = pane;
	contextMenuState.item = item;
	contextMenuState.coords = { x, y };
}

export function closeContextMenu(): void {
	contextMenuState.coords = null;
}

// ---- Favourites: per-viewer convenience, kept in this browser's storage ----
const FAV_KEY = 'pulsar_inventory:favourites';

function loadFavourites(): string[] {
	try {
		const raw = localStorage.getItem(FAV_KEY);
		const parsed = raw ? JSON.parse(raw) : [];
		return Array.isArray(parsed) ? parsed.filter((v): v is string => typeof v === 'string') : [];
	} catch {
		return [];
	}
}

export const favouritesState = $state({ names: loadFavourites() });

export function isFavourite(name: string): boolean {
	return favouritesState.names.includes(name);
}

export function toggleFavourite(name: string): void {
	favouritesState.names = isFavourite(name) ? favouritesState.names.filter((n) => n !== name) : [...favouritesState.names, name];
	try {
		localStorage.setItem(FAV_KEY, JSON.stringify(favouritesState.names));
	} catch {
		// storage blocked: the choice just lasts for this session
	}
}
