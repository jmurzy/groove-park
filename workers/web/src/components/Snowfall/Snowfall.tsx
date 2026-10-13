import type { CSSProperties } from "react";
import snowflake from "./images/snowflake.png";
import styles from "./Snowfall.module.css";

const flakes = [
	{ left: 3, size: 20, duration: 10, delay: -7, drift: 24 },
	{ left: 11, size: 34, duration: 14, delay: -2, drift: -32 },
	{ left: 18, size: 16, duration: 9, delay: -5, drift: 18 },
	{ left: 27, size: 26, duration: 12, delay: -10, drift: -26 },
	{ left: 36, size: 18, duration: 11, delay: -1, drift: 20 },
	{ left: 44, size: 38, duration: 15, delay: -12, drift: -38 },
	{ left: 53, size: 22, duration: 10, delay: -8, drift: 30 },
	{ left: 61, size: 16, duration: 13, delay: -4, drift: -18 },
	{ left: 68, size: 30, duration: 12, delay: -9, drift: 34 },
	{ left: 76, size: 20, duration: 9, delay: -3, drift: -22 },
	{ left: 84, size: 36, duration: 16, delay: -14, drift: 28 },
	{ left: 93, size: 18, duration: 11, delay: -6, drift: -26 },
] as const;

export function Snowfall() {
	return (
		<div aria-hidden="true" className={styles.snowfall}>
			{flakes.map((flake) => (
				<img
					alt=""
					className={styles.flake}
					key={flake.left}
					src={snowflake}
					style={
						{
							"--delay": `${flake.delay}s`,
							"--drift": `${flake.drift}px`,
							"--duration": `${flake.duration}s`,
							"--left": `${flake.left}%`,
							"--size": `${flake.size}px`,
						} as CSSProperties
					}
				/>
			))}
		</div>
	);
}
