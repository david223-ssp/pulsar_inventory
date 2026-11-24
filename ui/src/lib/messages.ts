// central NUI message router, forwards SendNUIMessage calls from client/*.lua to the inventory store

import { handleInventoryMessage } from './store/inventory.svelte';
import { applyHealthData, requestHealthData } from './health/health.svelte';

interface InboundMessage {
	type?: string;
	data?: unknown;
}

function route(type: string, data: unknown) {
	if (type === 'setHealthData') {
		applyHealthData(data);
		return;
	}
	handleInventoryMessage(type, data);
	// refresh the Health & Injuries tab every time the inventory opens
	if (type === 'APP_SHOW') void requestHealthData();
}

/** Returns an unsubscribe function */
export function attachMessageListener(): () => void {
	const handler = (event: MessageEvent<InboundMessage>) => {
		if (!event.isTrusted) return;
		if (event.data?.type) route(event.data.type, event.data.data);
	};
	window.addEventListener('message', handler);
	return () => window.removeEventListener('message', handler);
}

export { route as applyMessage };
