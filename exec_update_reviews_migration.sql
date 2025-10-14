-- Update reviews table migration
-- First, check if helpful_votes table already exists
DROP TABLE IF EXISTS helpful_votes;

-- Remove foreign key constraint for product_id
ALTER TABLE reviews DROP CONSTRAINT IF EXISTS fk_rails_bedd9094d4;

-- Remove product_id index
DROP INDEX IF EXISTS index_reviews_on_product_id;

-- Remove product_id column
ALTER TABLE reviews DROP COLUMN IF EXISTS product_id;

-- Rename comment to content
ALTER TABLE reviews RENAME COLUMN comment TO content;

-- Add reviewable polymorphic columns
ALTER TABLE reviews ADD COLUMN IF NOT EXISTS reviewable_type character varying;
ALTER TABLE reviews ADD COLUMN IF NOT EXISTS reviewable_id bigint;

-- Add helpful_count
ALTER TABLE reviews ADD COLUMN IF NOT EXISTS helpful_count integer DEFAULT 0 NOT NULL;

-- Rename user_id to reviewer_id
ALTER TABLE reviews RENAME COLUMN user_id TO reviewer_id;

-- Create helpful_votes table
CREATE TABLE helpful_votes (
  id bigserial PRIMARY KEY,
  user_id bigint NOT NULL,
  review_id bigint NOT NULL,
  created_at timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Add foreign keys
ALTER TABLE helpful_votes ADD CONSTRAINT fk_rails_helpful_votes_user 
  FOREIGN KEY (user_id) REFERENCES users(id);
  
ALTER TABLE helpful_votes ADD CONSTRAINT fk_rails_helpful_votes_review 
  FOREIGN KEY (review_id) REFERENCES reviews(id);

-- Add indexes
CREATE UNIQUE INDEX IF NOT EXISTS index_helpful_votes_on_user_id_and_review_id 
  ON helpful_votes(user_id, review_id);
  
CREATE UNIQUE INDEX IF NOT EXISTS idx_reviews_on_reviewer_and_reviewable 
  ON reviews(reviewer_id, reviewable_type, reviewable_id);
  
CREATE INDEX IF NOT EXISTS index_reviews_on_reviewable 
  ON reviews(reviewable_type, reviewable_id);

-- Insert migration record
INSERT INTO schema_migrations (version) VALUES ('20250922233340');