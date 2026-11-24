import { mount } from 'svelte';
import App from './App.svelte';
import './theme.css';

const target = document.getElementById('app');
if (!target) {
	throw new Error('#app mount node not found');
}

const app = mount(App, { target });

if (import.meta.env.DEV) {
	// in a normal browser, put a game screenshot behind the UI so it looks like it does over GTA (in FiveM the game is the backdrop).
	// The file lives in ui/dev/, outside the build, so it never ships
	Object.assign(document.body.style, {
		backgroundImage: 'url("/dev/background.webp")',
		backgroundSize: 'cover',
		backgroundRepeat: 'no-repeat',
		backgroundPosition: 'center',
	});

	// simulates ITEMS_LOADED/SET_ITEMS + a populated inventory so `bun run dev` shows a live panel, not bundled into production
	import('./lib/mock').then(({ startMock }) => startMock());
}

export default app;
