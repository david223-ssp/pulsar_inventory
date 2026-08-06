import { mount } from 'svelte';
import App from './App.svelte';
import './theme.css';

const target = document.getElementById('app');
if (!target) {
	throw new Error('#app mount node not found');
}

const app = mount(App, { target });

if (import.meta.env.DEV) {
	// simulates ITEMS_LOADED/SET_ITEMS + a populated inventory so `bun run dev` shows a live panel, not bundled into production
	import('./lib/mock').then(({ startMock }) => startMock());
}

export default app;
