create extension if not exists pgcrypto;

create table if not exists users (
	id uuid primary key default gen_random_uuid(),
	phone text not null unique,
	display_name text not null,
	avatar_media_id uuid,
	created_at timestamptz not null default now(),
	updated_at timestamptz not null default now()
);

create table if not exists chats (
	id uuid primary key default gen_random_uuid(),
	kind text not null,
	title text,
	created_by uuid not null references users(id) on delete cascade,
	created_at timestamptz not null default now()
);

create table if not exists chat_members (
	chat_id uuid not null references chats(id) on delete cascade,
	user_id uuid not null references users(id) on delete cascade,
	role text not null default 'member',
	joined_at timestamptz not null default now(),
	primary key (chat_id, user_id)
);

create table if not exists media (
	id uuid primary key default gen_random_uuid(),
	owner_id uuid not null references users(id) on delete cascade,
	object_key text not null,
	size bigint not null,
	mime text not null,
	created_at timestamptz not null default now()
);

create table if not exists messages (
	id uuid primary key default gen_random_uuid(),
	chat_id uuid not null references chats(id) on delete cascade,
	sender_id uuid not null references users(id) on delete cascade,
	body text,
	media_id uuid references media(id) on delete set null,
	created_at timestamptz not null default now(),
	edited_at timestamptz,
	deleted_at timestamptz
);

create index if not exists messages_chat_created_at_idx on messages (chat_id, created_at desc);

create table if not exists calls (
	id uuid primary key default gen_random_uuid(),
	chat_id uuid not null references chats(id) on delete cascade,
	room_name text not null,
	created_by uuid not null references users(id) on delete cascade,
	status text not null default 'active',
	created_at timestamptz not null default now()
);

create table if not exists devices (
	id uuid primary key default gen_random_uuid(),
	user_id uuid not null references users(id) on delete cascade,
	platform text not null,
	push_token text not null,
	created_at timestamptz not null default now(),
	updated_at timestamptz not null default now(),
	unique (user_id, platform, push_token)
);
