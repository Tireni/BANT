create or replace function public.ensure_profile(p_display_name text, p_username text)
returns public.profiles
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  cleaned_username text;
  base_username text;
  candidate_username text;
  profile_row public.profiles;
  attempt integer := 0;
begin
  if current_user_id is null then
    raise exception 'Not authenticated';
  end if;

  select *
  into profile_row
  from public.profiles
  where id = current_user_id;

  if found then
    return profile_row;
  end if;

  cleaned_username := lower(regexp_replace(coalesce(p_username, ''), '[^a-z0-9_]+', '_', 'g'));
  cleaned_username := regexp_replace(cleaned_username, '_+', '_', 'g');
  cleaned_username := trim(both '_' from cleaned_username);

  if length(cleaned_username) < 3 then
    cleaned_username := 'user_' || substring(current_user_id::text from 1 for 6);
  end if;

  base_username := substring(cleaned_username from 1 for 19);

  loop
    candidate_username := case
      when attempt = 0 then substring(base_username || '_' || substring(current_user_id::text from 1 for 4) from 1 for 24)
      else substring(base_username || '_' || substring(md5(current_user_id::text || attempt::text) from 1 for 4) from 1 for 24)
    end;

    begin
      insert into public.profiles (id, display_name, username, onboarding_completed, onboarding_step)
      values (
        current_user_id,
        coalesce(nullif(btrim(coalesce(p_display_name, '')), ''), 'BANT User'),
        candidate_username,
        false,
        1
      )
      returning *
      into profile_row;

      return profile_row;
    exception
      when unique_violation then
        attempt := attempt + 1;
        if attempt > 10 then
          raise exception 'Unable to generate a unique username';
        end if;
    end;
  end loop;
end;
$$;

grant execute on function public.ensure_profile(text, text) to authenticated;
