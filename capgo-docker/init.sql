-- Capgo self-hosted bootstrap. Idempotent: safe to run again after capgo updates.
-- Run via scripts/init-capgo.sh, which provides the psql variables below and
-- substitutes the RBAC catalog from capgo/supabase/seed.sql at the marker line.
--
--   :admin_id    auth.users id of the platform admin
--   :api_secret  API_SECRET from volumes/functions/.env (DB -> functions auth)
--   :db_url      base URL the database uses to call edge functions

SELECT
  set_config('capgo_init.admin_id', :'admin_id', false),
  set_config('capgo_init.api_secret', :'api_secret', false),
  set_config('capgo_init.db_url', :'db_url', false)
\g /dev/null

-- 1. Vault secrets (same names as capgo/supabase/seed.sql)
DO $$
DECLARE
  v_secrets jsonb := jsonb_build_object(
    'admin_users', jsonb_build_array(current_setting('capgo_init.admin_id'))::text,
    'db_url', current_setting('capgo_init.db_url'),
    'apikey', current_setting('capgo_init.api_secret'),
    'CAPGO_MFA_EMAIL_OTP_ENFORCED_AT', ''
  );
  v_name text;
  v_id uuid;
BEGIN
  FOR v_name IN SELECT jsonb_object_keys(v_secrets) LOOP
    SELECT id INTO v_id FROM vault.secrets WHERE name = v_name;
    IF v_id IS NULL THEN
      PERFORM vault.create_secret(v_secrets ->> v_name, v_name);
    ELSE
      PERFORM vault.update_secret(v_id, v_secrets ->> v_name);
    END IF;
  END LOOP;
END $$;

-- 2. RBAC permissions catalog. The prod baseline migration creates the schema
-- and roles, but permissions/role_permissions only come from seed.sql.
DO $$
BEGIN
-- @RBAC_CATALOG@
END $$;

-- 3. Storage buckets
INSERT INTO storage.buckets (id, name, public)
VALUES
  ('capgo', 'capgo', true),
  ('apps', 'apps', false),
  ('images', 'images', true)
ON CONFLICT (id) DO NOTHING;

-- 4. Unlimited plan. Org creation (public/organization/post.ts) picks the
-- smallest plan whose MAU fits, so with a single plan every org gets this one.
INSERT INTO public.plans (
  name, description, price_m, price_y, stripe_id, credit_id,
  price_m_id, price_y_id, storage, bandwidth, mau, market_desc, build_time_unit
)
VALUES (
  'Unlimited Self-Hosted', 'Maximum limits for self-hosted Capgo', 0, 0,
  'selfhosted-unlimited', 'selfhosted-unlimited', 'none', 'none',
  9223372036854775807, 9223372036854775807, 9223372036854775807,
  'Unlimited self-hosted plan', 9223372036854775807
)
ON CONFLICT (stripe_id) DO NOTHING;

-- 5. Every org is always on the unlimited plan. New orgs get a 15-day trial
-- with status NULL, which is_paying_and_good_plan_org_action rejects once it
-- expires; force a paid, never-exceeded subscription instead.
CREATE OR REPLACE FUNCTION public.selfhosted_force_unlimited_plan()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  NEW.product_id := 'selfhosted-unlimited';
  NEW.status := 'succeeded';
  NEW.is_good_plan := true;
  NEW.canceled_at := NULL;
  NEW.mau_exceeded := false;
  NEW.storage_exceeded := false;
  NEW.bandwidth_exceeded := false;
  NEW.build_time_exceeded := false;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER selfhosted_force_unlimited_plan
BEFORE INSERT OR UPDATE ON public.stripe_info
FOR EACH ROW EXECUTE FUNCTION public.selfhosted_force_unlimited_plan();

-- Existing subscriptions go through the trigger above
UPDATE public.stripe_info SET updated_at = now();

-- Orgs created without any subscription row
INSERT INTO public.stripe_info (customer_id)
SELECT 'selfhosted_' || o.id FROM public.orgs o WHERE o.customer_id IS NULL
ON CONFLICT DO NOTHING;

UPDATE public.orgs o
SET customer_id = 'selfhosted_' || o.id
WHERE o.customer_id IS NULL;
