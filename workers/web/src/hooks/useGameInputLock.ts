import { useEffect, type RefObject } from "react";

const pointerEvents = [
	"pointerdown",
	"pointerup",
	"pointermove",
	"pointerenter",
	"pointerleave",
	"click",
] as const;

const scrollKeys = new Set([
	"ArrowUp",
	"ArrowDown",
	"ArrowLeft",
	"ArrowRight",
	" ",
]);

export function useGameInputLock(
	canvasRef: RefObject<HTMLCanvasElement | null>,
	enabled: boolean,
) {
	useEffect(() => {
		const canvas = canvasRef.current;
		if (!enabled || !canvas) return;

		const preventPointerEvent = (event: Event) => {
			event.preventDefault();
			event.stopImmediatePropagation();
			canvas.focus();
		};
		const preventScroll = (event: KeyboardEvent) => {
			if (scrollKeys.has(event.key)) event.preventDefault();
		};

		// Web is keyboard/controller-only. Do not let a pointer click clear Godot UI focus.
		for (const eventName of pointerEvents) {
			canvas.addEventListener(eventName, preventPointerEvent, true);
		}
		// Keep gameplay controls from scrolling the page or activating focused browser UI.
		document.addEventListener("keydown", preventScroll);
		document.addEventListener("keyup", preventScroll);

		return () => {
			for (const eventName of pointerEvents) {
				canvas.removeEventListener(eventName, preventPointerEvent, true);
			}
			document.removeEventListener("keydown", preventScroll);
			document.removeEventListener("keyup", preventScroll);
		};
	}, [canvasRef, enabled]);
}
