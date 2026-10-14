import type { RefObject } from "react";

export function useFullscreen(targetRef: RefObject<HTMLElement | null>) {
	async function toggleFullscreen() {
		const target = targetRef.current;
		if (!target) return;

		try {
			if (document.fullscreenElement) await document.exitFullscreen();
			else await target.requestFullscreen();
		} catch {
			// Fullscreen is optional and browsers may reject it due to local policy.
		} finally {
			// Return keyboard input to the game after interacting with this control.
			target.focus();
		}
	}

	return toggleFullscreen;
}
