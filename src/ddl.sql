CREATE TABLE IF NOT EXISTS purchases (
    id                    SERIAL PRIMARY KEY,
    client_id             INTEGER NOT NULL,
    gender                CHAR(1),
    purchase_date         DATE NOT NULL,
    purchase_time_seconds INTEGER,
    purchase_datetime     TIMESTAMP,
    product_id            INTEGER NOT NULL,
    quantity              NUMERIC,
    price_per_item        NUMERIC,
    discount_per_item     NUMERIC,
    total_price           NUMERIC,
    load_date             DATE,
    source_date           DATE NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_purchases_source_date  ON purchases (source_date);
CREATE INDEX IF NOT EXISTS idx_purchases_purchase_date ON purchases (purchase_date);
CREATE INDEX IF NOT EXISTS idx_purchases_client_id    ON purchases (client_id);
CREATE INDEX IF NOT EXISTS idx_purchases_product_id   ON purchases (product_id);