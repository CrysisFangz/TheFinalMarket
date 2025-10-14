-- Execute all remaining migrations directly via SQL
-- This bypasses Rails initialization issues

-- 20250927000001_create_tags
CREATE TABLE IF NOT EXISTS tags (
  id bigserial PRIMARY KEY,
  name character varying NOT NULL,
  description character varying,
  slug character varying,
  products_count integer DEFAULT 0,
  created_at timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE UNIQUE INDEX IF NOT EXISTS index_tags_on_name ON tags(name);
CREATE UNIQUE INDEX IF NOT EXISTS index_tags_on_slug ON tags(slug);
INSERT INTO schema_migrations (version) VALUES ('20250927000001') ON CONFLICT DO NOTHING;

-- 20250927000002_create_product_tags
CREATE TABLE IF NOT EXISTS product_tags (
  id bigserial PRIMARY KEY,
  product_id bigint NOT NULL,
  tag_id bigint NOT NULL,
  created_at timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (product_id) REFERENCES products(id),
  FOREIGN KEY (tag_id) REFERENCES tags(id)
);
CREATE INDEX IF NOT EXISTS index_product_tags_on_product_id ON product_tags(product_id);
CREATE INDEX IF NOT EXISTS index_product_tags_on_tag_id ON product_tags(tag_id);
CREATE UNIQUE INDEX IF NOT EXISTS index_product_tags_on_product_id_and_tag_id ON product_tags(product_id, tag_id);
INSERT INTO schema_migrations (version) VALUES ('20250927000002') ON CONFLICT DO NOTHING;

-- 20250927000003_create_product_variants (option_types and option_values)
CREATE TABLE IF NOT EXISTS option_types (
  id bigserial PRIMARY KEY,
  name character varying NOT NULL,
  product_id bigint NOT NULL,
  position integer DEFAULT 0,
  created_at timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (product_id) REFERENCES products(id)
);
CREATE INDEX IF NOT EXISTS index_option_types_on_product_id ON option_types(product_id);
CREATE UNIQUE INDEX IF NOT EXISTS index_option_types_on_product_id_and_name ON option_types(product_id, name);

CREATE TABLE IF NOT EXISTS option_values (
  id bigserial PRIMARY KEY,
  name character varying NOT NULL,
  option_type_id bigint NOT NULL,
  position integer DEFAULT 0,
  created_at timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (option_type_id) REFERENCES option_types(id)
);
CREATE INDEX IF NOT EXISTS index_option_values_on_option_type_id ON option_values(option_type_id);
CREATE UNIQUE INDEX IF NOT EXISTS index_option_values_on_option_type_id_and_name ON option_values(option_type_id, name);

CREATE TABLE IF NOT EXISTS variants (
  id bigserial PRIMARY KEY,
  product_id bigint NOT NULL,
  sku character varying,
  price decimal(10,2),
  compare_at_price decimal(10,2),
  cost_price decimal(10,2),
  stock_quantity integer DEFAULT 0,
  weight decimal(10,2),
  barcode character varying,
  position integer DEFAULT 0,
  created_at timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (product_id) REFERENCES products(id)
);
CREATE INDEX IF NOT EXISTS index_variants_on_product_id ON variants(product_id);
CREATE UNIQUE INDEX IF NOT EXISTS index_variants_on_sku ON variants(sku);

CREATE TABLE IF NOT EXISTS variant_option_values (
  id bigserial PRIMARY KEY,
  variant_id bigint NOT NULL,
  option_value_id bigint NOT NULL,
  created_at timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (variant_id) REFERENCES variants(id),
  FOREIGN KEY (option_value_id) REFERENCES option_values(id)
);
CREATE INDEX IF NOT EXISTS index_variant_option_values_on_variant_id ON variant_option_values(variant_id);
CREATE INDEX IF NOT EXISTS index_variant_option_values_on_option_value_id ON variant_option_values(option_value_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_vov_on_variant_and_option_value ON variant_option_values(variant_id, option_value_id);

INSERT INTO schema_migrations (version) VALUES ('20250927000003') ON CONFLICT DO NOTHING;

-- 20250927000004_create_wishlists
CREATE TABLE IF NOT EXISTS wishlists (
  id bigserial PRIMARY KEY,
  user_id bigint NOT NULL,
  wishlist_items_count integer DEFAULT 0 NOT NULL,
  created_at timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id)
);
CREATE INDEX IF NOT EXISTS index_wishlists_on_user_id ON wishlists(user_id);

CREATE TABLE IF NOT EXISTS wishlist_items (
  id bigserial PRIMARY KEY,
  wishlist_id bigint NOT NULL,
  product_id bigint NOT NULL,
  created_at timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (wishlist_id) REFERENCES wishlists(id),
  FOREIGN KEY (product_id) REFERENCES products(id)
);
CREATE INDEX IF NOT EXISTS index_wishlist_items_on_wishlist_id ON wishlist_items(wishlist_id);
CREATE INDEX IF NOT EXISTS index_wishlist_items_on_product_id ON wishlist_items(product_id);
CREATE UNIQUE INDEX IF NOT EXISTS index_wishlist_items_on_wishlist_id_and_product_id ON wishlist_items(wishlist_id, product_id);

INSERT INTO schema_migrations (version) VALUES ('20250927000004') ON CONFLICT DO NOTHING;

-- 20250927000005_create_product_images
CREATE TABLE IF NOT EXISTS product_images (
  id bigserial PRIMARY KEY,
  product_id bigint NOT NULL,
  position integer NOT NULL,
  is_primary boolean DEFAULT false,
  alt_text character varying,
  created_at timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (product_id) REFERENCES products(id)
);
CREATE INDEX IF NOT EXISTS index_product_images_on_product_id ON product_images(product_id);
CREATE INDEX IF NOT EXISTS index_product_images_on_product_id_and_position ON product_images(product_id, position);
CREATE INDEX IF NOT EXISTS index_product_images_on_product_id_and_is_primary ON product_images(product_id, is_primary);

INSERT INTO schema_migrations (version) VALUES ('20250927000005') ON CONFLICT DO NOTHING;

-- 20250927000006_create_saved_items
CREATE TABLE IF NOT EXISTS saved_items (
  id bigserial PRIMARY KEY,
  user_id bigint NOT NULL,
  product_id bigint NOT NULL,
  variant_id bigint,
  note text,
  created_at timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id),
  FOREIGN KEY (product_id) REFERENCES products(id),
  FOREIGN KEY (variant_id) REFERENCES variants(id)
);
CREATE INDEX IF NOT EXISTS index_saved_items_on_user_id ON saved_items(user_id);
CREATE INDEX IF NOT EXISTS index_saved_items_on_product_id ON saved_items(product_id);
CREATE INDEX IF NOT EXISTS index_saved_items_on_variant_id ON saved_items(variant_id);
CREATE UNIQUE INDEX IF NOT EXISTS index_saved_items_on_user_product_variant ON saved_items(user_id, product_id, variant_id);

INSERT INTO schema_migrations (version) VALUES ('20250927000006') ON CONFLICT DO NOTHING;

-- 20250927000007_create_product_views
CREATE TABLE IF NOT EXISTS product_views (
  id bigserial PRIMARY KEY,
  user_id bigint NOT NULL,
  product_id bigint NOT NULL,
  view_count integer DEFAULT 1,
  last_viewed_at timestamp(6),
  created_at timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id),
  FOREIGN KEY (product_id) REFERENCES products(id)
);
CREATE INDEX IF NOT EXISTS index_product_views_on_user_id ON product_views(user_id);
CREATE INDEX IF NOT EXISTS index_product_views_on_product_id ON product_views(product_id);
CREATE UNIQUE INDEX IF NOT EXISTS index_product_views_on_user_id_and_product_id ON product_views(user_id, product_id);
CREATE INDEX IF NOT EXISTS index_product_views_on_last_viewed_at ON product_views(last_viewed_at);

INSERT INTO schema_migrations (version) VALUES ('20250927000007') ON CONFLICT DO NOTHING;

-- 20250927000008_create_product_comparisons
CREATE TABLE IF NOT EXISTS compare_lists (
  id bigserial PRIMARY KEY,
  user_id bigint NOT NULL,
  created_at timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id)
);
CREATE INDEX IF NOT EXISTS index_compare_lists_on_user_id ON compare_lists(user_id);

CREATE TABLE IF NOT EXISTS compare_items (
  id bigserial PRIMARY KEY,
  compare_list_id bigint NOT NULL,
  product_id bigint NOT NULL,
  created_at timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (compare_list_id) REFERENCES compare_lists(id),
  FOREIGN KEY (product_id) REFERENCES products(id)
);
CREATE INDEX IF NOT EXISTS index_compare_items_on_compare_list_id ON compare_items(compare_list_id);
CREATE INDEX IF NOT EXISTS index_compare_items_on_product_id ON compare_items(product_id);
CREATE UNIQUE INDEX IF NOT EXISTS index_compare_items_on_compare_list_id_and_product_id ON compare_items(compare_list_id, product_id);

INSERT INTO schema_migrations (version) VALUES ('20250927000008') ON CONFLICT DO NOTHING;

-- 20250927194737_create_dispute_evidences
CREATE TABLE IF NOT EXISTS dispute_evidences (
  id bigserial PRIMARY KEY,
  title character varying NOT NULL,
  description text NOT NULL,
  dispute_id bigint NOT NULL,
  user_id bigint NOT NULL,
  created_at timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (dispute_id) REFERENCES disputes(id),
  FOREIGN KEY (user_id) REFERENCES users(id)
);
CREATE INDEX IF NOT EXISTS index_dispute_evidences_on_dispute_id ON dispute_evidences(dispute_id);
CREATE INDEX IF NOT EXISTS index_dispute_evidences_on_user_id ON dispute_evidences(user_id);
CREATE INDEX IF NOT EXISTS index_dispute_evidences_on_dispute_id_and_created_at ON dispute_evidences(dispute_id, created_at);

INSERT INTO schema_migrations (version) VALUES ('20250927194737') ON CONFLICT DO NOTHING;

-- Final message
SELECT 'Migrations executed successfully!' as status;
SELECT COUNT(*) as total_migrations FROM schema_migrations;