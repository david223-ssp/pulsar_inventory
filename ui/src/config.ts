/*
	Pulsar Inventory content config
	Server owners: edit rarity/item-type labels, ignored metadata keys, and formatting rules here
	
	For colors/fonts, edit theme.css instead
*/

export interface RarityInfo {
	label: string;
	color: string;
}

// Colors read from theme.css's --rarity-N custom properties at render time
export const RARITY: Record<number, RarityInfo> = {
	1: { label: 'Common', color: 'var(--rarity-1)' },
	2: { label: 'Uncommon', color: 'var(--rarity-2)' },
	3: { label: 'Rare', color: 'var(--rarity-3)' },
	4: { label: 'Epic', color: 'var(--rarity-4)' },
	5: { label: 'Objective', color: 'var(--rarity-5)' },
	6: { label: 'Legendary', color: 'var(--rarity-6)' },
	7: { label: 'Exotic', color: 'var(--rarity-7)' },
};

export function getRarityLabel(rarity: number | undefined): string {
	return RARITY[rarity ?? -1]?.label ?? 'Dogshit';
}

export function getRarityColor(rarity: number | undefined): string {
	return RARITY[rarity ?? -1]?.color ?? 'var(--color-text)';
}

// common (rarity 1) skips the border highlight, too much visual noise since almost everything is common
export function getRarityBorderColor(rarity: number | undefined): string | undefined {
	return (rarity ?? 1) > 1 ? getRarityColor(rarity) : undefined;
}

export const ITEM_TYPES: Record<number, string> = {
	1: 'Consumable',
	2: 'Weapon',
	3: 'Tool',
	4: 'Crafting Ingredient',
	5: 'Collectable',
	6: 'Junk',
	8: 'Evidence',
	9: 'Ammunition',
	10: 'Container',
	11: 'Gem',
	12: 'Paraphernalia',
	13: 'Wearable',
	14: 'Contraband',
	15: 'Collectable (Gang Chain)',
	16: 'Weapon Attachment',
	17: 'Crafting Schematic',
	18: 'Device',
	19: 'Explosive Device',
};

export function getTypeLabel(type: number | undefined): string {
	return ITEM_TYPES[type ?? -1] ?? 'Unknown';
}

// keys hidden from a tooltip's generic key/value list, add your own custom keys here
export const IGNORED_METADATA_FIELDS = new Set([
	'ammo',
	'clip',
	'CreateDate',
	'Container',
	'Quality',
	'mask',
	'accessory',
	'watch',
	'hat',
	'BankId',
	'VpnName',
	'EvidenceCoords',
	'EvidenceType',
	'EvidenceWeapon',
	'EvidenceDNA',
	'WeaponTint',
	'CustomItemLabel',
	'CustomItemImage',
	'CustomItemAction',
	'Items',
	'Department',
	'Scratched',
	'PoliceWeaponId',
	'Mugshot',
	'CustomAmt',
	'Inviter',
	'Brew',
]);

// Shown when a slot references an item id with no matching catalog definition
export const FALLBACK_ITEM = {
	name: 'ph',
	label: 'Invalid Item',
	description: "An item in your inventory is missing its item definition, try /reloaditems and if this doesn't fix it please report this",
	invalid: true,
	price: 0,
	isStackable: false,
	type: -1,
	rarity: -1,
	weight: 0,
};

export const HOTBAR_SLOTS = 5;
export const HOTBAR_AUTOHIDE_MS = 5000;
export const CHANGE_ALERT_DURATION_MS = 3000;
export const CHANGE_ALERTS_MAX = 5;
export const CRAFT_THROTTLE_MS = 3000;

export const CURRENCY = new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD', maximumFractionDigits: 0 });

// Keeps shop price badges to 3-4 characters so they never overflow the slot corner
export function formatShopPrice(amount: number): string {
	if (amount >= 1_000_000) return `$${(amount / 1_000_000).toFixed(1).replace(/\.0$/, '')}M`;
	if (amount >= 1_000) return `$${(amount / 1_000).toFixed(1).replace(/\.0$/, '')}K`;
	return `$${amount}`;
}
