import { useEffect, useState } from "react";

declare global {
	interface Window {
		GAME_MUTED?: boolean;
		GAME_ON_MUTED_CHANGE?: (muted: boolean) => void;
		GAME_SET_MUTED?: (muted: boolean) => void;
	}
}

export function useMute() {
	// Start muted: browsers can reject audio that starts before player interaction.
	const [muted, setMuted] = useState(() =>
		typeof window === "undefined" ? true : (window.GAME_MUTED ?? true),
	);

	useEffect(() => {
		const onMutedChange = (nextMuted: boolean) => setMuted(nextMuted);
		window.GAME_ON_MUTED_CHANGE = onMutedChange;
		setMuted(window.GAME_MUTED ?? true);

		return () => {
			if (window.GAME_ON_MUTED_CHANGE === onMutedChange) {
				window.GAME_ON_MUTED_CHANGE = undefined;
			}
		};
	}, []);

	function toggleMute() {
		const setGameMuted = window.GAME_SET_MUTED;
		if (!setGameMuted) return;

		const nextMuted = !muted;
		setGameMuted(nextMuted);
	}

	return { muted, toggleMute };
}
