// The short "where is this item" word in the tooltip eyebrow (ox_inventory's getInventoryKind)
import { getPane } from '../store/inventory.svelte';
import type { PaneId } from '../types';

export function paneKind(pane: PaneId | undefined): string {
	if (!pane) return 'Item';
	if (pane === 'player') return 'Pockets';
	if (pane === 'backpack') return 'Backpack';
	if (pane === 'equipment') return 'Equipped';
	const p = getPane(pane);
	if (p.shop) return 'Shop';
	const owner = String(p.owner ?? '');
	if (p.invType === 10 || owner.startsWith('dropzone')) return 'Ground';
	if (owner.startsWith('container:')) return 'Container';
	if (owner.startsWith('stash:')) return 'Stash';
	if (p.invType === 4) return 'Trunk';
	if (p.invType === 5) return 'Glovebox';
	return 'Storage';
}
