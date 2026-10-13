import styles from "./LoadingBar.module.css";

type LoadingBarProps = {
	current: number;
	total: number;
};

export function LoadingBar({ current, total }: LoadingBarProps) {
	const isDeterminate = total > 0;
	const percent = isDeterminate
		? Math.min(100, Math.round((current / total) * 100))
		: 0;

	return (
		<div
			aria-label={isDeterminate ? `Loading game: ${percent}%` : "Loading game"}
			aria-valuemax={100}
			aria-valuemin={0}
			aria-valuenow={isDeterminate ? percent : undefined}
			className={`${styles.progress} ${
				isDeterminate ? "" : styles.indeterminate
			}`}
			role="progressbar"
		>
			<div
				className={styles.fill}
				style={isDeterminate ? { width: `${percent}%` } : undefined}
			/>
			<span className={styles.label}>
				{isDeterminate ? `LOADING ${percent}%` : "LOADING..."}
			</span>
		</div>
	);
}
