// Floating placement shared by the hover tooltip and the context menu (same @floating-ui setup as ox_inventory):
// both anchor to a point (the cursor / the right-click) instead of an element
import { computePosition, flip, offset, shift, type Middleware, type Placement } from '@floating-ui/dom';

export const pointer = { x: 0, y: 0 };

if (typeof window !== 'undefined') {
	window.addEventListener('mousemove', (e) => {
		pointer.x = e.clientX;
		pointer.y = e.clientY;
	}, { passive: true });
}

function pointRef(x: number, y: number) {
	return {
		getBoundingClientRect: () => ({ width: 0, height: 0, x, y, left: x, top: y, right: x, bottom: y }),
	};
}

export async function placeAtPoint(
	el: HTMLElement,
	x: number,
	y: number,
	placement: Placement,
	middleware: Middleware[],
): Promise<{ x: number; y: number; placement: Placement }> {
	return computePosition(pointRef(x, y), el, { placement, middleware, strategy: 'fixed' });
}

// tooltip: right of the cursor, 10px off on both axes, flipping/shifting to stay on screen
export const TOOLTIP_MIDDLEWARE = [offset({ mainAxis: 10, crossAxis: 10 }), flip(), shift({ padding: 8 })];
// menu: just under the click point
export const MENU_MIDDLEWARE = [offset({ mainAxis: 4 }), flip(), shift({ padding: 8 })];
