-- Batch execute remaining simple migrations
-- Migration: 20250927000001_create_tags

CREATE TABLE IF NOT EXISTS tags (
  id bigserial PRIMARY KEY,
  name character varying NOT NULL,
  description character varying,
  slug character varying,
  products_count integer DEFAULT 0,
  created_at timestamp(6) NOT NULL,
  updated_at timestamp(6) NOT NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS index_tags_on_name ON tags(name);
CREATE UNIQUE INDEX IF NOT EXISTS index_tags_on_slug ON tags(slug);

INSERT INTO schema_migrations (version) VALUES ('20250927000001') ON CONFLICT DO NOTHING;