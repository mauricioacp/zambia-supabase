export interface StrapiAgreement {
  id: number;
  email: string;
  documentNumber: string;
  phone: string;
  createdAt: string;
  updatedAt: string;
  headQuarters: string;
  role: string;
  name: string | null;
  lastName: string;
  country: string;
  address: string | null;
  volunteeringAgreement: boolean;
  ethicalDocumentAgreement: boolean;
  ageVerification: boolean;
  signDataPath: string;
  mailingAgreementa: boolean;
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
  role_id: string | null;
  user_id: string | null;
  headquarter_id: string | null;
  season_id: string | null;
  status?: string; // 'active', 'inactive', 'prospect' (default: 'prospect')
  email: string;
  document_number?: string | null;
  phone?: string | null;
  created_at?: string | null; // TIMESTAMPTZ (ISO 8601 string format)
  updated_at?: string | null;
  name?: string | null;
  last_name?: string | null;
  address?: string | null;
  volunteering_agreement?: boolean | null;
  ethical_document_agreement?: boolean | null;
  mailing_agreement?: boolean | null;
  age_verification?: boolean | null;
  signature_data?: string | null;
}

export interface SupabaseLookupItem {
  id: string;
  name: string;
}
