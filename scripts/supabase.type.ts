export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  graphql_public: {
    Tables: {
      [_ in never]: never
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      graphql: {
        Args: {
          operationName?: string
          query?: string
          variables?: Json
          extensions?: Json
        }
        Returns: Json
      }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
  public: {
    Tables: {
      agreements: {
        Row: {
          address: string | null
          age_verification: boolean | null
          created_at: string | null
          document_number: string | null
          email: string
          ethical_document_agreement: boolean | null
          headquarter_id: string | null
          id: string
          last_name: string | null
          mailing_agreement: boolean | null
          name: string | null
          phone: string | null
          role_id: string
          season_id: string | null
          signature_data: string | null
          status: string | null
          updated_at: string | null
          user_id: string | null
          volunteering_agreement: boolean | null
        }
        Insert: {
          address?: string | null
          age_verification?: boolean | null
          created_at?: string | null
          document_number?: string | null
          email: string
          ethical_document_agreement?: boolean | null
          headquarter_id?: string | null
          id?: string
          last_name?: string | null
          mailing_agreement?: boolean | null
          name?: string | null
          phone?: string | null
          role_id: string
          season_id?: string | null
          signature_data?: string | null
          status?: string | null
          updated_at?: string | null
          user_id?: string | null
          volunteering_agreement?: boolean | null
        }
        Update: {
          address?: string | null
          age_verification?: boolean | null
          created_at?: string | null
          document_number?: string | null
          email?: string
          ethical_document_agreement?: boolean | null
          headquarter_id?: string | null
          id?: string
          last_name?: string | null
          mailing_agreement?: boolean | null
          name?: string | null
          phone?: string | null
          role_id?: string
          season_id?: string | null
          signature_data?: string | null
          status?: string | null
          updated_at?: string | null
          user_id?: string | null
          volunteering_agreement?: boolean | null
        }
        Relationships: [
          {
            foreignKeyName: "agreements_headquarter_id_fkey"
            columns: ["headquarter_id"]
            isOneToOne: false
            referencedRelation: "headquarters"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "agreements_role_id_fkey"
            columns: ["role_id"]
            isOneToOne: false
            referencedRelation: "roles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "agreements_season_id_fkey"
            columns: ["season_id"]
            isOneToOne: false
            referencedRelation: "seasons"
            referencedColumns: ["id"]
          },
        ]
      }
      collaborators: {
        Row: {
          agreement_id: string | null
          end_date: string | null
          headquarter_id: string | null
          id: string
          role_id: string | null
          start_date: string | null
          status: string | null
          user_id: string | null
        }
        Insert: {
          agreement_id?: string | null
          end_date?: string | null
          headquarter_id?: string | null
          id?: string
          role_id?: string | null
          start_date?: string | null
          status?: string | null
          user_id?: string | null
        }
        Update: {
          agreement_id?: string | null
          end_date?: string | null
          headquarter_id?: string | null
          id?: string
          role_id?: string | null
          start_date?: string | null
          status?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "collaborators_agreement_id_fkey"
            columns: ["agreement_id"]
            isOneToOne: false
            referencedRelation: "agreement_with_role"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "collaborators_agreement_id_fkey"
            columns: ["agreement_id"]
            isOneToOne: false
            referencedRelation: "agreements"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "collaborators_headquarter_id_fkey"
            columns: ["headquarter_id"]
            isOneToOne: false
            referencedRelation: "headquarters"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "collaborators_role_id_fkey"
            columns: ["role_id"]
            isOneToOne: false
            referencedRelation: "roles"
            referencedColumns: ["id"]
          },
        ]
      }
      countries: {
        Row: {
          code: string
          created_at: string | null
          id: string
          name: string
          status: string | null
          updated_at: string | null
        }
        Insert: {
          code: string
          created_at?: string | null
          id?: string
          name: string
          status?: string | null
          updated_at?: string | null
        }
        Update: {
          code?: string
          created_at?: string | null
          id?: string
          name?: string
          status?: string | null
          updated_at?: string | null
        }
        Relationships: []
      }
      events: {
        Row: {
          created_at: string | null
          description: string | null
          end_datetime: string | null
          headquarter_id: string | null
          id: string
          location: Json | null
          season_id: string | null
          start_datetime: string | null
          status: string | null
          title: string
          updated_at: string | null
        }
        Insert: {
          created_at?: string | null
          description?: string | null
          end_datetime?: string | null
          headquarter_id?: string | null
          id?: string
          location?: Json | null
          season_id?: string | null
          start_datetime?: string | null
          status?: string | null
          title: string
          updated_at?: string | null
        }
        Update: {
          created_at?: string | null
          description?: string | null
          end_datetime?: string | null
          headquarter_id?: string | null
          id?: string
          location?: Json | null
          season_id?: string | null
          start_datetime?: string | null
          status?: string | null
          title?: string
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "events_headquarter_id_fkey"
            columns: ["headquarter_id"]
            isOneToOne: false
            referencedRelation: "headquarters"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "events_season_id_fkey"
            columns: ["season_id"]
            isOneToOne: false
            referencedRelation: "seasons"
            referencedColumns: ["id"]
          },
        ]
      }
      headquarters: {
        Row: {
          address: string | null
          contact_info: Json | null
          country_id: string | null
          created_at: string | null
          id: string
          name: string
          status: string | null
          updated_at: string | null
        }
        Insert: {
          address?: string | null
          contact_info?: Json | null
          country_id?: string | null
          created_at?: string | null
          id?: string
          name: string
          status?: string | null
          updated_at?: string | null
        }
        Update: {
          address?: string | null
          contact_info?: Json | null
          country_id?: string | null
          created_at?: string | null
          id?: string
          name?: string
          status?: string | null
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "headquarters_country_id_fkey"
            columns: ["country_id"]
            isOneToOne: false
            referencedRelation: "countries"
            referencedColumns: ["id"]
          },
        ]
      }
      processes: {
        Row: {
          applicable_roles: string[] | null
          content: Json | null
          created_at: string | null
          description: string | null
          id: string
          name: string
          status: string | null
          type: string | null
          updated_at: string | null
          version: string | null
        }
        Insert: {
          applicable_roles?: string[] | null
          content?: Json | null
          created_at?: string | null
          description?: string | null
          id?: string
          name: string
          status?: string | null
          type?: string | null
          updated_at?: string | null
          version?: string | null
        }
        Update: {
          applicable_roles?: string[] | null
          content?: Json | null
          created_at?: string | null
          description?: string | null
          id?: string
          name?: string
          status?: string | null
          type?: string | null
          updated_at?: string | null
          version?: string | null
        }
        Relationships: []
      }
      roles: {
        Row: {
          code: string
          created_at: string | null
          description: string | null
          id: string
          level: number
          name: string
          permissions: Json | null
          status: string | null
          updated_at: string | null
        }
        Insert: {
          code: string
          created_at?: string | null
          description?: string | null
          id?: string
          level: number
          name: string
          permissions?: Json | null
          status?: string | null
          updated_at?: string | null
        }
        Update: {
          code?: string
          created_at?: string | null
          description?: string | null
          id?: string
          level?: number
          name?: string
          permissions?: Json | null
          status?: string | null
          updated_at?: string | null
        }
        Relationships: []
      }
      seasons: {
        Row: {
          created_at: string | null
          end_date: string | null
          headquarter_id: string | null
          id: string
          manager_id: string | null
          name: string
          start_date: string | null
          status: string | null
          updated_at: string | null
        }
        Insert: {
          created_at?: string | null
          end_date?: string | null
          headquarter_id?: string | null
          id?: string
          manager_id?: string | null
          name: string
          start_date?: string | null
          status?: string | null
          updated_at?: string | null
        }
        Update: {
          created_at?: string | null
          end_date?: string | null
          headquarter_id?: string | null
          id?: string
          manager_id?: string | null
          name?: string
          start_date?: string | null
          status?: string | null
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "seasons_headquarter_id_fkey"
            columns: ["headquarter_id"]
            isOneToOne: false
            referencedRelation: "headquarters"
            referencedColumns: ["id"]
          },
        ]
      }
      strapi_migrations: {
        Row: {
          created_at: string
          error_message: string | null
          id: number
          last_migrated_at: string
          migration_timestamp: string
          records_processed: number
          status: string
        }
        Insert: {
          created_at?: string
          error_message?: string | null
          id?: never
          last_migrated_at: string
          migration_timestamp?: string
          records_processed?: number
          status: string
        }
        Update: {
          created_at?: string
          error_message?: string | null
          id?: never
          last_migrated_at?: string
          migration_timestamp?: string
          records_processed?: number
          status?: string
        }
        Relationships: []
      }
      students: {
        Row: {
          agreement_id: string | null
          enrollment_date: string | null
          headquarter_id: string | null
          id: string
          program_progress_comments: Json | null
          season_id: string | null
          status: string | null
          user_id: string | null
        }
        Insert: {
          agreement_id?: string | null
          enrollment_date?: string | null
          headquarter_id?: string | null
          id?: string
          program_progress_comments?: Json | null
          season_id?: string | null
          status?: string | null
          user_id?: string | null
        }
        Update: {
          agreement_id?: string | null
          enrollment_date?: string | null
          headquarter_id?: string | null
          id?: string
          program_progress_comments?: Json | null
          season_id?: string | null
          status?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "students_agreement_id_fkey"
            columns: ["agreement_id"]
            isOneToOne: false
            referencedRelation: "agreement_with_role"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "students_agreement_id_fkey"
            columns: ["agreement_id"]
            isOneToOne: false
            referencedRelation: "agreements"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "students_headquarter_id_fkey"
            columns: ["headquarter_id"]
            isOneToOne: false
            referencedRelation: "headquarters"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "students_season_id_fkey"
            columns: ["season_id"]
            isOneToOne: false
            referencedRelation: "seasons"
            referencedColumns: ["id"]
          },
        ]
      }
      workshops: {
        Row: {
          capacity: number | null
          created_at: string | null
          description: string | null
          end_datetime: string | null
          facilitator_id: string | null
          headquarter_id: string | null
          id: string
          name: string
          season_id: string | null
          start_datetime: string | null
          status: string | null
          updated_at: string | null
        }
        Insert: {
          capacity?: number | null
          created_at?: string | null
          description?: string | null
          end_datetime?: string | null
          facilitator_id?: string | null
          headquarter_id?: string | null
          id?: string
          name: string
          season_id?: string | null
          start_datetime?: string | null
          status?: string | null
          updated_at?: string | null
        }
        Update: {
          capacity?: number | null
          created_at?: string | null
          description?: string | null
          end_datetime?: string | null
          facilitator_id?: string | null
          headquarter_id?: string | null
          id?: string
          name?: string
          season_id?: string | null
          start_datetime?: string | null
          status?: string | null
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "workshops_facilitator_id_fkey"
            columns: ["facilitator_id"]
            isOneToOne: false
            referencedRelation: "collaborators"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "workshops_headquarter_id_fkey"
            columns: ["headquarter_id"]
            isOneToOne: false
            referencedRelation: "headquarters"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "workshops_season_id_fkey"
            columns: ["season_id"]
            isOneToOne: false
            referencedRelation: "seasons"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      agreement_with_role: {
        Row: {
          address: string | null
          age_verification: boolean | null
          created_at: string | null
          document_number: string | null
          email: string | null
          ethical_document_agreement: boolean | null
          headquarter_id: string | null
          id: string | null
          last_name: string | null
          mailing_agreement: boolean | null
          name: string | null
          phone: string | null
          role: Json | null
          season_id: string | null
          signature_data: string | null
          status: string | null
          updated_at: string | null
          user_id: string | null
          volunteering_agreement: boolean | null
        }
        Relationships: [
          {
            foreignKeyName: "agreements_headquarter_id_fkey"
            columns: ["headquarter_id"]
            isOneToOne: false
            referencedRelation: "headquarters"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "agreements_season_id_fkey"
            columns: ["season_id"]
            isOneToOne: false
            referencedRelation: "seasons"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Functions: {
      get_agreement_by_role_id: {
        Args: { role_id: string }
        Returns: {
          address: string | null
          age_verification: boolean | null
          created_at: string | null
          document_number: string | null
          email: string | null
          ethical_document_agreement: boolean | null
          headquarter_id: string | null
          id: string | null
          last_name: string | null
          mailing_agreement: boolean | null
          name: string | null
          phone: string | null
          role: Json | null
          season_id: string | null
          signature_data: string | null
          status: string | null
          updated_at: string | null
          user_id: string | null
          volunteering_agreement: boolean | null
        }[]
      }
      get_agreement_with_role_by_id: {
        Args: { p_agreement_id: string }
        Returns: Json
      }
      get_agreements_by_role: {
        Args: { role_name: string }
        Returns: {
          address: string | null
          age_verification: boolean | null
          created_at: string | null
          document_number: string | null
          email: string | null
          ethical_document_agreement: boolean | null
          headquarter_id: string | null
          id: string | null
          last_name: string | null
          mailing_agreement: boolean | null
          name: string | null
          phone: string | null
          role: Json | null
          season_id: string | null
          signature_data: string | null
          status: string | null
          updated_at: string | null
          user_id: string | null
          volunteering_agreement: boolean | null
        }[]
      }
      get_agreements_by_role_string: {
        Args: { role_string: string }
        Returns: {
          address: string | null
          age_verification: boolean | null
          created_at: string | null
          document_number: string | null
          email: string | null
          ethical_document_agreement: boolean | null
          headquarter_id: string | null
          id: string | null
          last_name: string | null
          mailing_agreement: boolean | null
          name: string | null
          phone: string | null
          role: Json | null
          season_id: string | null
          signature_data: string | null
          status: string | null
          updated_at: string | null
          user_id: string | null
          volunteering_agreement: boolean | null
        }[]
      }
      get_agreements_with_role: {
        Args: Record<PropertyKey, never>
        Returns: {
          address: string | null
          age_verification: boolean | null
          created_at: string | null
          document_number: string | null
          email: string | null
          ethical_document_agreement: boolean | null
          headquarter_id: string | null
          id: string | null
          last_name: string | null
          mailing_agreement: boolean | null
          name: string | null
          phone: string | null
          role: Json | null
          season_id: string | null
          signature_data: string | null
          status: string | null
          updated_at: string | null
          user_id: string | null
          volunteering_agreement: boolean | null
        }[]
      }
      get_agreements_with_role_paginated: {
        Args: {
          p_limit?: number
          p_offset?: number
          p_status?: string
          p_headquarter_id?: string
          p_season_id?: string
          p_search?: string
          p_role_id?: string
        }
        Returns: Json
      }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DefaultSchema = Database[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof Database },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof Database
  }
    ? keyof (Database[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        Database[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never,
> = DefaultSchemaTableNameOrOptions extends { schema: keyof Database }
  ? (Database[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      Database[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof Database },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof Database
  }
    ? keyof Database[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends { schema: keyof Database }
  ? Database[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof Database },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof Database
  }
    ? keyof Database[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends { schema: keyof Database }
  ? Database[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof Database },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof Database
  }
    ? keyof Database[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
> = DefaultSchemaEnumNameOrOptions extends { schema: keyof Database }
  ? Database[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof Database },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof Database
  }
    ? keyof Database[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never,
> = PublicCompositeTypeNameOrOptions extends { schema: keyof Database }
  ? Database[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  graphql_public: {
    Enums: {},
  },
  public: {
    Enums: {},
  },
} as const

