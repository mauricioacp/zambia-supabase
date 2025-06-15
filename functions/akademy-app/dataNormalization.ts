/**
 * this transformation is added due to bad normalization in a Strapi database.
 */
export const headquartersNormalization = new Map<string, string>([
  ["konsejo de direccion", "konsejo akademiko"],
  ["consejo de direccion", "konsejo akademiko"],
  ["cdmx", "ciudad de mexico"],
  ["valencia ruzafa/ribera alta", "valencia nomada upv"],
  ["valencia", "valencia nomada upv"],
  ["webinarseptiembre", "webinar septiembre"],
  ["webinar-septiembre", "webinar septiembre"],
  ["webinarfeb", "webinar marzo"],
  ["webinar feb", "webinar marzo"],
  ["webinar febrero", "webinar marzo"],
  ["webinar-marzo", "webinar marzo"],
]);

export const rolesNormalization = new Map<string, string>([
  ["equipo de comunicacion", "director/a de comunicacion local"],
  ["equipo comunicacion", "director/a de comunicacion local"],
  ["comunicacion", "director/a de comunicacion local"],
  ["otro", "asistente a la direccion"],
  ["konsejo de direccion", "miembro del konsejo de direccion"],
  ["consejo de direccion", "miembro del konsejo de direccion"],
]);

export const normalizeText = (text: string): string => {
  return text?.trim().toLowerCase().normalize("NFD")
  .replace(/[\u0300-\u036f]/g, "") ?? "";
};

export const normalizeHeadquarters = (headquarters: string): string => {
  const normalized = normalizeText(headquarters);
  return headquartersNormalization.get(normalized) || normalized;
};

export const normalizeRole = (role: string): string => {
  const normalized = normalizeText(role);
  return rolesNormalization.get(normalized) || normalized;
};
