create table if not exists e2e_identity_keys (
	user_id uuid primary key references users(id) on delete cascade,
	public_key bytea not null,
	updated_at timestamptz not null default now()
);

create table if not exists e2e_prekeys (
	id bigint primary key,
	user_id uuid not null references users(id) on delete cascade,
	public_key bytea not null,
	created_at timestamptz not null default now(),
	consumed_at timestamptz
);

create table if not exists e2e_signed_prekeys (
	id bigint primary key,
	user_id uuid not null references users(id) on delete cascade,
	public_key bytea not null,
	signature bytea not null,
	created_at timestamptz not null default now(),
	expires_at timestamptz
);
