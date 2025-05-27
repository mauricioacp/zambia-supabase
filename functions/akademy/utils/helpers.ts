/**
 * Formats a date string to ISO format for Supabase timestamp columns
 * @param dateStr
 * @returns ISO formatted date string or null
 */
export function formatIsoDate(dateStr: string): string {
	try {
		const date = new Date(dateStr);
		if (isNaN(date.getTime())) {
			console.warn(`Failed to parse date: ${dateStr}`);
			return new Date().toISOString();
		}
		return date.toISOString();
	} catch (error) {
		console.warn(`Failed to parse date: ${dateStr}`, error);
		return new Date().toISOString();
	}
}

function parseRawDate(rawDate: string): Date {
	const date = new Date(rawDate);
	if (isNaN(date.getTime())) {
		console.warn(`Failed to parse date: ${rawDate}`);
		return new Date();
	}
	return date;
}

export function isCreatedMoreThanOneYearAgo(rawDate: string): boolean {
	const ONE_YEAR_IN_MS = 365 * 24 * 60 * 60 * 1000;
	const date = parseRawDate(rawDate);
	const oneYearAgo = new Date(Date.now() - ONE_YEAR_IN_MS);
	return date <= oneYearAgo;
}