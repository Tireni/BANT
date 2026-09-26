export type Profile = {
  id: string;
  display_name: string;
  username: string;
  university_id: string | null;
  university_name?: string | null;
  university_short_name?: string | null;
  bio: string | null;
  avatar_url: string | null;
  onboarding_completed: boolean;
  onboarding_step: number;
  user_status: "student" | "non_student" | null;
  occupation_category: "lecturer" | "business" | "professional" | "graduate" | "job_seeker" | "creator" | "other" | null;
  occupation_custom: string | null;
  institution_source: "directory" | "manual" | null;
  created_at: string;
  updated_at: string;
};

export type Interest = {
  id: string;
  name: string;
  slug: string;
};
