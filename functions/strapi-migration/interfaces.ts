export interface StrapiAgreement {
	id: number;
	email: string;
	documentNumber: string;
	phone: string;
	createdAt: string;
	updatedAt: string;
	headQuarters: string;
	role: string;
	name: string;
	lastName: string;
	country: string;
	address: string;
	volunteeringAgreement: boolean;
	ethicalDocumentAgreement: boolean;
	ageVerification: boolean;
	signDataPath: string;
	mailingAgreement: boolean;
}

export interface StrapiResponse<T> {
	data: T[];
	meta?: {
		pagination?: {
			page: number;
			pageSize: number;
			pageCount: number;
			total: number;
		};
	};
}

export interface SupabaseAgreement {
	user_id: string | null;
	headquarter_id: string;
	season_id: string;
	status: string; // 'active', 'graduated', 'inactive', 'prospect'
	email: string;
	document_number: string;
	phone: string;
	created_at: string; // ISO 8601 timestamp
	updated_at?: string;
	name?: string;
	last_name?: string;
	address?: string;
	volunteering_agreement?: boolean;
	ethical_document_agreement?: boolean;
	mailing_agreement?: boolean;
	age_verification?: boolean;
	signature_data?: string;
	role_id: string;
}

export interface SupabaseLookupItem {
	id: string;
	name: string;
}
