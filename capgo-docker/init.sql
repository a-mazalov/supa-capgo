--delete from vault.secrets;
--ALTER DATABASE postgres SET search_path TO "$user", public, extensions;

insert into
  "auth"."users" (
    "instance_id",
    "id",
    "aud",
    "role",
    "email",
    "encrypted_password",
    "email_confirmed_at",
    "invited_at",
    "confirmation_token",
    "confirmation_sent_at",
    "recovery_token",
    "recovery_sent_at",
    "email_change_token_new",
    "email_change",
    "email_change_sent_at",
    "last_sign_in_at",
    "raw_app_meta_data",
    "raw_user_meta_data",
    "is_super_admin",
    "created_at",
    "updated_at",
    "phone",
    "phone_confirmed_at",
    "phone_change",
    "phone_change_token",
    "phone_change_sent_at",
    "email_change_token_current",
    "email_change_confirm_status",
    "banned_until",
    "reauthentication_token",
    "reauthentication_sent_at"
  )
values
  (
    '00000000-0000-0000-0000-000000000000',
    '03bc2292-ceb5-477b-b3ae-73dc55148f37',
    'authenticated',
    'authenticated',
    'admin@kali.by',
    '$2a$10$QJ/6Val3U.3KMr0psrNi1.X4o9jdeCnubN9hxddeqH824DCZwGsNK', --_W
    NOW(),
    NOW(),
    '',
    NOW(),
    '',
    null,
    '',
    '',
    null,
    NOW(),
    '{"provider": "email", "providers": ["email"]}',
    null,
    'f',
    NOW(),
    NOW(),
    null,
    null,
    '',
    '',
    null,
    '',
    0,
    null,
    '',
    null
  );


DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM vault.secrets WHERE name = 'admin_users') THEN
        PERFORM vault.create_secret('["03bc2292-ceb5-477b-b3ae-73dc55148f37"]', 'admin_users', 'admins user id');
    END IF;
END $$;

insert into
  "storage"."buckets" (
    "id",
    "name",
    "owner",
    "created_at",
    "updated_at",
    "public"
  )
values
  ('capgo', 'capgo', null, NOW(), NOW(), 't'),
  ('apps', 'apps', null, NOW(), NOW(), 'f'),
  ('images', 'images', null, NOW(), NOW(), 't');

insert into
  public.plans (
    created_at,
    updated_at,
    name,
    description,
    price_m,
    price_y,
    stripe_id,
    credit_id,
    id,
    price_m_id,
    price_y_id,
    storage,
    bandwidth,
    mau,
    market_desc,
    build_time_unit
  )
values
  (
    NOW(),
    NOW(),
    'Unlimited Self-Hosted',
    'Maximum limits for self-hosted Capgo',
    0,
    0,
    'selfhosted-unlimited',
    'prod_TJRd2hFHZsBIPK',
    gen_random_uuid(),
    'none',
    'none',
    9223372036854775807::bigint, -- max storage (~9EB)
    9223372036854775807::bigint, -- max bandwidth (~9EB)
    9223372036854775807::bigint, -- max MAU (~9 quintillion)
    'Unlimited self-hosted plan',
    9223372036854775807::bigint -- max build time
  );

insert into
  "public"."stripe_info" (
    "created_at",
    "updated_at",
    "subscription_id",
    "customer_id",
    "status",
    "product_id",
    "trial_at",
    "price_id",
    "is_good_plan",
    "plan_usage",
    "subscription_anchor_start",
    "subscription_anchor_end",
    "mau_exceeded",
    "bandwidth_exceeded",
    "storage_exceeded",
    "build_time_exceeded"
  )
values
  (
    NOW(),
    NOW(),
    'subscribe_admin',
    'customer_admin', -- потом использовать этот id для организации
    'succeeded',
    'selfhosted-unlimited', --product_id
    NOW() + interval '15 days',
    null,
    't',
    2,
    NOW() - interval '15 days',
    NOW() + interval '100 years',
    false,
    false,
    false,
    false
  );

update orgs
set
  customer_id = 'customer_admin'
where
  id = (
    select
      id
    from
      orgs
    order by
      id
    limit
      1
  );
