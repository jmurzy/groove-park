import { useEffect, useRef, useState } from "react";

declare global {
	interface Window {
		GAME_MUTED?: boolean;
		GAME_ON_MUTED_CHANGE?: (muted: boolean) => void;
		GAME_SET_MUTED?: (muted: boolean) => void;
		GAME_ENABLE_AUDIO?: () => void;
	}
}

export function useMute(audioActivationReady: boolean) {
	// Start muted: browsers can reject audio that starts before player interaction.
	const [muted, setMuted] = useState(() =>
		typeof window === "undefined" ? true : (window.GAME_MUTED ?? true),
	);
	const audioActivationHandled = useRef(false);

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

	useEffect(() => {
		if (!audioActivationReady) return;

		const activateAudio = (event: KeyboardEvent) => {
			if (event.repeat || audioActivationHandled.current) return;

			const enableGameAudio = window.GAME_ENABLE_AUDIO;
			if (!enableGameAudio) return;

			audioActivationHandled.current = true;
			enableGameAudio();
		};

		window.addEventListener("keydown", activateAudio);
		return () => window.removeEventListener("keydown", activateAudio);
	}, [audioActivationReady]);

	function toggleMute() {
		const nextMuted = !muted;
		if (nextMuted) {
			const setGameMuted = window.GAME_SET_MUTED;
			if (!setGameMuted) return;
			// Manual controls always take precedence over automatic first-input audio.
			audioActivationHandled.current = true;
			setGameMuted(true);
		} else {
			const enableGameAudio = window.GAME_ENABLE_AUDIO;
			if (!enableGameAudio) return;
			// Manual controls always take precedence over automatic first-input audio.
			audioActivationHandled.current = true;
			enableGameAudio();
		}
	}

	return { muted, toggleMute };
}
