// Mirrors the exact shapes client/*.lua sends/expects

export interface ItemComponent {
	/** Keyed by weapon model/name (or its `.weapon` alias) -> whether this attachment fits */
	strings: Record<string, boolean>;
}

export interface ItemDefinition {
	name: string;
	label: string;
	description?: string;
	price: number;
	isUsable?: boolean;
	isRemoved?: boolean;
	/** Max stack size, or `false`/`0` if not stackable */
	isStackable: number | false;
	type: number;
	rarity: number;
	metalic?: boolean;
	weight: number;
	/** Durability lifespan in seconds, if the item degrades over time */
	durability?: number;
	requiresLicense?: boolean;
	qualification?: string;
	/** Weapon-attachment fitment data, present only on type 16 (Weapon Attachment) items */
	component?: ItemComponent;
	/** Schematic id this item teaches, if craftable via a schematic unlock */
	schematic?: string;
	iconOverride?: string;
	staticMetadata?: Record<string, unknown> | string;
	invalid?: boolean;
}

export interface EvidenceColor {
	r: number;
	g: number;
	b: number;
}

export interface ChopListEntry {
	name: string;
	hv?: boolean;
}

export interface AccessCodeEntry {
	label: string;
	code: string;
}

// Every metadata field this UI renders a dedicated line for; the rest fall through to a generic line
export interface ItemMetaData {
	SerialNumber?: string;
	ScratchedSerialNumber?: boolean;
	StateID?: string | number;
	PassportID?: string | number;
	DOB?: string | number;
	EvidenceAmmoType?: string;
	EvidenceId?: string | number;
	EvidenceColor?: EvidenceColor;
	EvidenceDegraded?: boolean;
	EvidenceBloodPool?: boolean;
	CustomItemText?: string;
	VaultCode?: string;
	BranchName?: string;
	Finished?: number;
	CryptoCoin?: number;
	ChopList?: ChopListEntry[];
	WeaponComponents?: Record<string, { item: string }>;
	AccessCodes?: AccessCodeEntry[];
	MethTable?: string | number;
	CustomItemLabel?: string;
	CustomItemImage?: string;
	Quality?: number;
	[key: string]: unknown;
}

export interface InventorySlotItem {
	Name: string;
	Slot: number;
	Count: number;
	/** Unix seconds */
	CreateDate: number;
	/** Either a real object, or (as received from Lua) a Lua-table-literal string, see lib/util/metadata.ts */
	MetaData?: ItemMetaData | string;
	Quality?: number;
	/** Present on shop-flavored panes */
	Price?: number;
	id?: number | string;
}

export type PaneId = 'player' | 'secondary';

export interface PaneAction {
	icon: string;
	text: string;
	event: string;
}

export interface PaneState {
	loaded: boolean;
	size: number;
	invType: number;
	name: string;
	inventory: (InventorySlotItem | null)[];
	disabled: Record<number, boolean>;
	owner: string | number;
	capacity: number;
	isWeaponEligble?: boolean;
	qualifications?: string[];
	shop?: boolean;
	free?: boolean;
	playerShop?: boolean;
	modifyShop?: boolean;
	class?: number;
	model?: number;
	slotOverride?: number;
	capacityOverride?: number;
	action?: PaneAction;
}

export interface RecipeIngredient {
	name: string;
	count: number;
}

export interface Recipe {
	id: string;
	result: RecipeIngredient;
	items: RecipeIngredient[];
	/** Whether this recipe uses the per-recipe cooldown at all, some recipes have none */
	cooldown?: number;
}

/** Keyed by recipe id -> a unix-ms timestamp the cooldown ends at */
export type Cooldowns = Record<string, number>;

export type ChangeAlertType = 'add' | 'removed' | 'used' | 'Holstered' | 'Equipped';

export interface ChangeAlert {
	id: number;
	type: ChangeAlertType;
	item: string;
	count: number;
}

export interface InventorySettings {
	muted: boolean;
	useBank: boolean;
}

// Move/Merge/Swap NUI callback payload, identical field set across all three
export interface MoveSlotPayload {
	ownerFrom: string | number;
	ownerTo: string | number;
	slotFrom: number;
	slotTo: number;
	name: string;
	countFrom: number;
	countTo: number;
	invTypeFrom: number;
	invTypeTo: number;
	vehClassFrom?: number;
	vehClassTo?: number;
	vehModelFrom?: number;
	vehModelTo?: number;
	slotOverrideFrom?: number;
	slotOverrideTo?: number;
	capacityOverrideFrom?: number;
	capacityOverrideTo?: number;
	isSplit?: boolean;
}
