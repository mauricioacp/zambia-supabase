/**
 * this transformation is added due to bad normalization in a Strapi database.
 */
export const headquartersNormalization = new Map<string, string>([
	['konsejo de dirección', 'konsejo akademíko'],
	['cdmx', 'ciudad de méxico'],
	['valencia ruzafa/ribera alta', 'valencia nómada upv'],
	['valencia', 'valencia nómada upv'],
	['webinarseptiembre', 'webinar septiembre'],
	['webinar-septiembre', 'webinar septiembre'],
	['webinarfeb', 'webinar marzo'],
	['webinar feb', 'webinar marzo'],
	['webinar febrero', 'webinar marzo'],
]);

export const rolesNormalization = new Map<string, string>([
	['equipo de comunicación', 'director/a de comunicación local'],
	['otro', 'asistente a la dirección'],
	['comunicación', 'director/a de comunicación local'],
	['equipo comunicación', 'director/a de comunicación local'],
]);

export const normalizeText = (text: string): string => {
	return text?.trim().toLowerCase() ?? '';
};

export const normalizeHeadquarters = (headquarters: string): string => {
	const normalized = normalizeText(headquarters);
	return headquartersNormalization.get(normalized) || normalized;
};

export const normalizeRole = (role: string): string => {
	const normalized = normalizeText(role);
	return rolesNormalization.get(normalized) || normalized;
};
