// outbound UI -> Lua transport, see client/inventory.lua and client/crafting.lua for the handlers

import type { InventorySlotItem, MoveSlotPayload } from './types';

const RESOURCE_NAME = 'pulsar_inventory';

async function send(event: string, data: unknown = {}): Promise<void> {
	if (import.meta.env.DEV) return;
	try {
		await fetch(`https://${RESOURCE_NAME}/${event}`, {
			method: 'post',
			headers: { 'Content-Type': 'application/json; charset=UTF-8' },
			body: JSON.stringify(data),
		});
	} catch {
		// Expected to fail outside the actual NUI browser
	}
}

async function sendJson<T>(event: string, data: unknown, devValue: T): Promise<T> {
	if (import.meta.env.DEV) return devValue;
	try {
		const res = await fetch(`https://${RESOURCE_NAME}/${event}`, {
			method: 'post',
			headers: { 'Content-Type': 'application/json; charset=UTF-8' },
			body: JSON.stringify(data),
		});
		return (await res.json()) as T;
	} catch {
		return devValue;
	}
}

export interface CraftResult {
	inventory?: InventorySlotItem[];
	cooldowns?: Record<string, number>;
}

export interface AddToShopPayload {
	ownerFrom: string | number;
	invTypeFrom: number;
	slotFrom: number;
	ownerTo: string | number;
	invTypeTo: number;
	slotTo: number;
	price: number;
	quantity: number;
}

export interface DropToGroundPayload {
	ownerFrom: string | number;
	invTypeFrom: number;
	slotFrom: number;
	name: string;
	count: number;
	vehClassFrom?: number;
	vehModelFrom?: number;
	slotOverrideFrom?: number;
	capacityOverrideFrom?: number;
}

export const Nui = {
	// raw string payload, not an object, matches the Lua side's RegisterNUICallback
	frontEndSound: (sound: string) => send('FrontEndSound', sound),
	updateSettings: (settings: { muted?: boolean; useBank?: boolean }) => send('UpdateSettings', settings),
	submitAction: (owner: string | number, invType: number) => send('SubmitAction', { owner, invType }),
	close: () => send('Close'),
	crashed: () => send('Crashed'),
	sendNotify: (alert: 'success' | 'warning' | 'error', message: string, time?: number) => send('SendNotify', { alert, message, time }),
	useItem: (owner: string | number, slot: number, invType: number) => {
		void send('FrontEndSound', 'SELECT');
		return send('UseItem', { owner, slot, invType });
	},

	mergeSlot: (payload: MoveSlotPayload) => send('MergeSlot', payload),
	swapSlot: (payload: MoveSlotPayload) => send('SwapSlot', payload),
	moveSlot: (payload: MoveSlotPayload) => send('MoveSlot', payload),

	addToShop: (payload: AddToShopPayload) => sendJson<unknown>('AddToShop', payload, { success: true }),
	dropToGround: (payload: DropToGroundPayload) => send('DropToGround', payload),

	craft: (bench: string, qty: number, result: string) => sendJson<CraftResult | false>('Crafting:Craft', { bench, qty, result }, { inventory: undefined, cooldowns: {} }),
};
