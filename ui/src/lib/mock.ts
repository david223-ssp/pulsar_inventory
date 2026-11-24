// Dev-only simulated Lua message stream. Query params:
//   ?mode=crafting            opens straight into the crafting bench
//   (no ?secondary=)          a ground "Drop" pane, the default view (matches the Figma frame)
//   ?secondary=none           player inventory only
//   ?secondary=ground         a ground/dropzone pane, no prices
//   ?backpack=0               starts with the backpack slot empty (drag the spare backpack from slot 6 in)
//   ?tab=health|crafting|...  opens on a given top-nav tab
//   ?hotbar=1                 also pops the hotbar + equipped weapon overlay
//   ?health=0                 no setHealthData (Health & Injuries tab shows as unavailable)
//   ?secondary=shop           a fixed shop pane
//   ?secondary=playershop     a player-shop pane in modify mode

import { applyMessage } from './messages';
import { devHooks, equipmentPane } from './store/inventory.svelte';
import type { ItemDefinition, InventorySlotItem, PaneState, Recipe } from './types';

const ITEMS: Record<string, ItemDefinition> = {
	water: { name: 'water', label: 'Bottled Water', description: 'Refreshing.', price: 5, isUsable: true, isStackable: 20, type: 1, rarity: 1, weight: 0.5 },
	bandage: { name: 'bandage', label: 'Bandage', description: 'Stops the bleeding.', price: 25, isUsable: true, isStackable: 10, type: 1, rarity: 2, weight: 0.3 },
	phone: { name: 'phone', label: 'Phone', description: 'Stay connected.', price: 500, isUsable: true, isStackable: false, type: 3, rarity: 3, weight: 1.2 },
	lockpick: { name: 'lockpick', label: 'Lockpick', description: 'For emergencies.', price: 50, isUsable: true, isStackable: 5, type: 3, rarity: 2, weight: 0.2, durability: 3600 },
	repairkit: { name: 'repairkit', label: 'Repair Kit', description: 'Patch up your ride.', price: 350, isUsable: true, isStackable: 3, type: 3, rarity: 3, weight: 2, durability: 7200 },
	moneybag: { name: 'moneybag', label: 'Money Bag', description: "Don't ask where it's from.", price: 0, isStackable: 10, type: 6, rarity: 4, weight: 1 },
	WEAPON_ADVANCEDRIFLE: {
		name: 'WEAPON_ADVANCEDRIFLE',
		label: 'Advanced Rifle',
		description: 'Fully licensed, of course.',
		requiresLicense: true,
		price: 15000,
		isUsable: true,
		isStackable: false,
		type: 2,
		rarity: 5,
		weight: 4,
		durability: 86400,
	},
	backpack: { name: 'backpack', label: 'Backpack', description: 'Equip it in the backpack slot to carry more.', price: 250, isUsable: true, isStackable: false, type: 10, rarity: 1, weight: 3, container: 301, backpack: true, iconOverride: 'parachute' },
	cigar: { name: 'cigar', label: 'Russian Cream', description: 'A fine hand-rolled cigar.', price: 40, isUsable: true, isStackable: 10, type: 1, rarity: 6, weight: 0.1 },
	parachute: { name: 'parachute', label: 'Parachute', description: 'Pull the cord.', price: 250, isUsable: true, isStackable: false, type: 13, rarity: 1, weight: 0.1 },
	armor: { name: 'armor', label: 'Armor', description: 'Light body armor.', price: 300, isUsable: true, isStackable: 5, type: 13, rarity: 1, weight: 0.1 },
	WEAPON_COMBATPISTOL: { name: 'WEAPON_COMBATPISTOL', label: 'Pistol XM3', description: 'Compact sidearm.', requiresLicense: true, price: 2500, isUsable: true, isStackable: false, type: 2, rarity: 1, weight: 3 },
	scrapmetal: { name: 'scrapmetal', label: 'Scrap Metal', description: 'Salvaged parts.', price: 8, isStackable: 50, type: 4, rarity: 1, weight: 0.4 },
	cloth: { name: 'cloth', label: 'Cloth', description: 'Woven fabric.', price: 4, isStackable: 50, type: 4, rarity: 1, weight: 0.1 },
	tape: { name: 'tape', label: 'Duct Tape', description: 'Fixes anything.', price: 6, isStackable: 20, type: 4, rarity: 1, weight: 0.1 },
	plastic: { name: 'plastic', label: 'Plastic', description: 'Molded plastic sheeting.', price: 7, isStackable: 50, type: 4, rarity: 1, weight: 0.2 },
	wiring: { name: 'wiring', label: 'Wiring', description: 'Copper wiring.', price: 10, isStackable: 50, type: 4, rarity: 2, weight: 0.15 },
};

// Mirrors the Figma frame: cigar in 1, parachute in 5, pistol in 10, rifle in 15; the rest below the fold
const PLAYER_INVENTORY: InventorySlotItem[] = [
	{ Name: 'cigar', Slot: 1, Count: 1, CreateDate: Date.now() / 1000 },
	{ Name: 'parachute', Slot: 5, Count: 1, CreateDate: Date.now() / 1000 },
	{ Name: 'WEAPON_COMBATPISTOL', Slot: 10, Count: 1, CreateDate: Date.now() / 1000, MetaData: { SerialNumber: '210-774' } },
	// Three different wear levels so all three durability-meter tiers (high/green, mid/amber, low/red) are visible at once in dev
	{ Name: 'WEAPON_ADVANCEDRIFLE', Slot: 15, Count: 1, CreateDate: Date.now() / 1000 - 3600 * 2, MetaData: { SerialNumber: '482-119' } },
	{ Name: 'water', Slot: 21, Count: 6, CreateDate: Date.now() / 1000 },
	{ Name: 'bandage', Slot: 22, Count: 3, CreateDate: Date.now() / 1000 },
	{ Name: 'repairkit', Slot: 23, Count: 1, CreateDate: Date.now() / 1000 - 6480 },
	{ Name: 'lockpick', Slot: 24, Count: 2, CreateDate: Date.now() / 1000 - 1800 },
	{ Name: 'scrapmetal', Slot: 26, Count: 14, CreateDate: Date.now() / 1000 },
	{ Name: 'cloth', Slot: 27, Count: 3, CreateDate: Date.now() / 1000 },
	{ Name: 'tape', Slot: 28, Count: 6, CreateDate: Date.now() / 1000 },
	{ Name: 'plastic', Slot: 29, Count: 2, CreateDate: Date.now() / 1000 },
	// a spare backpack to drag into the backpack slot
	{ Name: 'backpack', Slot: 6, Count: 1, CreateDate: Date.now() / 1000, MetaData: { Container: 'bp_2' } },
];

const BACKPACK_INVENTORY: InventorySlotItem[] = [
	{ Name: 'cigar', Slot: 1, Count: 1, CreateDate: Date.now() / 1000 },
	{ Name: 'parachute', Slot: 5, Count: 1, CreateDate: Date.now() / 1000 },
	{ Name: 'WEAPON_COMBATPISTOL', Slot: 10, Count: 1, CreateDate: Date.now() / 1000 },
];

const GROUND_INVENTORY: InventorySlotItem[] = [
	{ Name: 'cigar', Slot: 1, Count: 1, CreateDate: Date.now() / 1000 },
	{ Name: 'parachute', Slot: 5, Count: 1, CreateDate: Date.now() / 1000 },
	{ Name: 'WEAPON_COMBATPISTOL', Slot: 10, Count: 1, CreateDate: Date.now() / 1000 },
	{ Name: 'WEAPON_ADVANCEDRIFLE', Slot: 15, Count: 1, CreateDate: Date.now() / 1000 - 3600 },
	{ Name: 'moneybag', Slot: 18, Count: 1, CreateDate: Date.now() / 1000 },
];

// Prices set per-slot, matching how a real shop stock row arrives from the server
const SHOP_INVENTORY: InventorySlotItem[] = [
	{ Name: 'water', Slot: 1, Count: 999, CreateDate: Date.now() / 1000, Price: 5 },
	{ Name: 'bandage', Slot: 2, Count: 999, CreateDate: Date.now() / 1000, Price: 25 },
	{ Name: 'repairkit', Slot: 3, Count: 50, CreateDate: Date.now() / 1000, Price: 350 },
	{ Name: 'WEAPON_ADVANCEDRIFLE', Slot: 5, Count: 10, CreateDate: Date.now() / 1000, Price: 15000 },
];

const PLAYERSHOP_INVENTORY: InventorySlotItem[] = [
	{ Name: 'moneybag', Slot: 1, Count: 4, CreateDate: Date.now() / 1000, Price: 800 },
	{ Name: 'lockpick', Slot: 2, Count: 2, CreateDate: Date.now() / 1000, Price: 75 },
];

const RECIPES: Recipe[] = [
	{ id: 'recipe_bandage', result: { name: 'bandage', count: 3 }, items: [{ name: 'water', count: 2 }] },
	{ id: 'recipe_lockpick', result: { name: 'lockpick', count: 1 }, items: [{ name: 'phone', count: 1 }, { name: 'water', count: 5 }] },
	{ id: 'recipe_repairkit', result: { name: 'repairkit', count: 1 }, items: [{ name: 'moneybag', count: 2 }] },
	// A 5-reagent recipe to check the mats list's wrap/scroll behavior
	{
		id: 'recipe_advancedrifle',
		result: { name: 'WEAPON_ADVANCEDRIFLE', count: 1 },
		items: [{ name: 'scrapmetal', count: 12 }, { name: 'cloth', count: 2 }, { name: 'tape', count: 4 }, { name: 'plastic', count: 3 }, { name: 'wiring', count: 6 }],
	},
];

export function startMock(): void {
	const params = new URLSearchParams(window.location.search);
	const startInCrafting = params.get('mode') === 'crafting';
	const secondaryFlavor = params.get('secondary') ?? 'ground';
	const showBackpack = params.get('backpack') !== '0';
	const startTab = params.get('tab');

	setTimeout(() => {
		applyMessage('SET_ITEMS', { items: ITEMS });
		applyMessage('ITEMS_LOADED', {});

		const playerPane: Partial<PaneState> = {
			loaded: true,
			size: 40,
			invType: 1,
			name: 'Xoticz Dev',
			inventory: PLAYER_INVENTORY,
			disabled: {},
			owner: 1,
			capacity: 100,
			isWeaponEligble: true,
		};
		applyMessage('SET_PLAYER_INVENTORY', playerPane);

		if (secondaryFlavor !== 'none') {
			applyMessage('SHOW_SECONDARY_INVENTORY', {});

			const secondaryPane: Partial<PaneState> =
				secondaryFlavor === 'shop'
					? { loaded: true, size: 20, invType: 6, name: 'Fleeca Deluxe', inventory: SHOP_INVENTORY, disabled: {}, owner: 'shop_1', capacity: 100000, shop: true }
					: secondaryFlavor === 'playershop'
						? {
								loaded: true,
								size: 20,
								invType: 11,
								name: 'My Shop',
								inventory: PLAYERSHOP_INVENTORY,
								disabled: {},
								owner: 1,
								capacity: 10000,
								playerShop: true,
								modifyShop: true,
							}
						: { loaded: true, size: 25, invType: 10, name: 'Drop', inventory: GROUND_INVENTORY, disabled: {}, owner: 'dropzone_1', capacity: 500 };
			applyMessage('SET_SECONDARY_INVENTORY', secondaryPane);
		}

		// Fakes the server's Inventory:Client:Equipment push: equipment pane + the worn backpack's storage
		const backpackStorage: Record<string, InventorySlotItem[]> = { 'container:bp_1': BACKPACK_INVENTORY, 'container:bp_2': [] };
		const pushEquipment = () => {
			const worn = equipmentPane.inventory.find((i) => i?.Slot === 1);
			const container = worn ? (worn.MetaData as { Container?: string } | undefined)?.Container : undefined;
			if (worn && container) {
				const owner = `container:${container}`;
				applyMessage('SET_BACKPACK_INVENTORY', { loaded: true, size: 15, invType: 301, name: 'Backpack', inventory: backpackStorage[owner] ?? [], disabled: {}, owner, capacity: 40 });
			} else {
				applyMessage('HIDE_BACKPACK_INVENTORY', {});
			}
		};
		devHooks.equipmentChanged = () => setTimeout(pushEquipment, 300);

		applyMessage('SET_EQUIPMENT_INVENTORY', {
			loaded: true,
			size: 6,
			invType: 300,
			name: 'Equipment',
			owner: 'SID-1',
			capacity: 1000,
			disabled: {},
			inventory: showBackpack ? [{ Name: 'backpack', Slot: 1, Count: 1, CreateDate: Date.now() / 1000, MetaData: { Container: 'bp_1' } }] : [],
		});
		applyMessage('SET_EQUIPMENT', { keybinds: { phone: 'M' } });
		pushEquipment();

		if (params.get('hotbar') === '1') {
			applyMessage('HOTBAR_SHOW', { items: [PLAYER_INVENTORY[0], PLAYER_INVENTORY[1]] });
			applyMessage('SET_EQUIPPED', { item: PLAYER_INVENTORY[3] });
		}

		applyMessage('ADD_ALERT', { alert: { id: 1, type: 'add', item: 'water', count: 6 } });
		applyMessage('ADD_ALERT', { alert: { id: 2, type: 'used', item: 'bandage', count: 1 } });
		applyMessage('ADD_ALERT', { alert: { id: 3, type: 'removed', item: 'lockpick', count: 2 } });

		if (startInCrafting) {
			applyMessage('SET_BENCH', { bench: 'workbench_1', cooldowns: { recipe_lockpick: Date.now() + 1000 * 60 * 12 }, recipes: RECIPES });
		}

		if (startTab === 'health' || startTab === 'crafting' || startTab === 'experience') applyMessage('SET_TAB', { tab: startTab });

		// pulsar_damage's shape: injuries keyed by part; keys are mixed on purpose to exercise the normalizer
		if (params.get('health') !== '0') {
			applyMessage('setHealthData', {
				available: true,
				health: 100,
				armor: 0,
				stamina: 0,
				injuries: {
					LARM: { damage: 85, bleeding: 1 },
					['right-leg']: { damage: 55, bleeding: 0 },
					head: { damage: 20, bleeding: 0 },
				},
				thresholds: { major: 40, critical: 70 },
				healItems: ['bandage', 'firstaid', 'ifak', 'gauze', 'tourniquet'],
			});
		}

		applyMessage('APP_SHOW', {});
	}, 200);
}
