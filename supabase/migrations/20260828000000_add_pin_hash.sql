-- Adds the column that stores each user's hashed security PIN, used by the
-- reset-password-with-pin Edge Function to verify identity when resetting
-- a password without email.
--
-- Only the SHA-256 hash is ever stored — never the raw PIN.
alter table public.profiles
  add column if not exists pin_hash text;
