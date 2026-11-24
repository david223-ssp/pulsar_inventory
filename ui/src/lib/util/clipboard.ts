// NUI has no async clipboard permission, so copy through a throwaway input (same trick ox_inventory uses)
export function setClipboard(value: string): void {
	const el = document.createElement('input');
	el.value = value;
	document.body.appendChild(el);
	el.select();
	document.execCommand('copy');
	document.body.removeChild(el);
}
