-- ============================================================================
-- Snowflake Postgres: Create Tables
-- ============================================================================
-- Run this directly against your Snowflake Postgres instance using psql or
-- any PostgreSQL client.
--
-- Connection string format:
-- postgres://<user>:<password>@<host>:5432/postgres?sslmode=require
--
-- Database: postgres
-- Schema: public (default)
-- ============================================================================

-- Product Reviews table (OLTP source - written in Postgres, synced to Snowflake)
CREATE TABLE IF NOT EXISTS product_reviews (
    review_id SERIAL PRIMARY KEY,
    product_id BIGINT,
    customer_id BIGINT,
    review_date DATE,
    rating BIGINT,
    review_title VARCHAR(200),
    review_text TEXT,
    verified_purchase BOOLEAN
);

-- Support Tickets table (OLTP source - written in Postgres, synced to Snowflake)
CREATE TABLE IF NOT EXISTS support_tickets (
    ticket_id SERIAL PRIMARY KEY,
    customer_id BIGINT,
    ticket_date TIMESTAMP,
    category VARCHAR(50),
    priority VARCHAR(20),
    subject VARCHAR(200),
    description TEXT,
    resolution TEXT,
    status VARCHAR(20)
);

-- Create indexes for common queries
CREATE INDEX IF NOT EXISTS idx_reviews_product_id ON product_reviews(product_id);
CREATE INDEX IF NOT EXISTS idx_reviews_customer_id ON product_reviews(customer_id);
CREATE INDEX IF NOT EXISTS idx_reviews_rating ON product_reviews(rating);
CREATE INDEX IF NOT EXISTS idx_tickets_customer_id ON support_tickets(customer_id);
CREATE INDEX IF NOT EXISTS idx_tickets_status ON support_tickets(status);
CREATE INDEX IF NOT EXISTS idx_tickets_priority ON support_tickets(priority);
