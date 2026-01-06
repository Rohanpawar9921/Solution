-- =========================================================
-- DATABASE SCHEMA: INVENTORY & SUPPLY MANAGEMENT
-- =========================================================

-- =========================================================
-- COMPANY
-- One company can have multiple warehouses
-- Acts as the top-level ownership boundary
-- =========================================================
CREATE TABLE companies (
    id          BIGINT PRIMARY KEY,
    name        VARCHAR(255) NOT NULL,
    created_at  TIMESTAMP NOT NULL
);

-- =========================================================
-- WAREHOUSE
-- Warehouses belong to a company
-- Location stored as TEXT to keep it flexible
-- =========================================================
CREATE TABLE warehouses (
    id          BIGINT PRIMARY KEY,
    company_id  BIGINT NOT NULL,
    name        VARCHAR(255),
    location    TEXT,
    created_at  TIMESTAMP NOT NULL,

    CONSTRAINT fk_warehouse_company
        FOREIGN KEY (company_id) REFERENCES companies(id)
);

-- =========================================================
-- PRODUCT
-- SKU is globally unique (explicit business rule)
-- Price stored as DECIMAL to avoid floating-point issues
-- is_bundle helps distinguish normal products and bundles
-- =========================================================
CREATE TABLE products (
    id          BIGINT PRIMARY KEY,
    company_id  BIGINT NOT NULL,
    name        VARCHAR(255) NOT NULL,
    sku         VARCHAR(100) NOT NULL,
    price       DECIMAL(10,2) NOT NULL,
    is_bundle   BOOLEAN DEFAULT FALSE,
    created_at  TIMESTAMP NOT NULL,

    CONSTRAINT uq_products_sku UNIQUE (sku),
    CONSTRAINT fk_product_company
        FOREIGN KEY (company_id) REFERENCES companies(id)
);

-- =========================================================
-- PRODUCT BUNDLES
-- Defines bundle composition (product contains other products)
-- Self-referencing many-to-many relationship
-- Supports nested bundles
-- =========================================================
CREATE TABLE product_bundles (
    bundle_product_id   BIGINT NOT NULL,
    child_product_id    BIGINT NOT NULL,
    quantity            INT NOT NULL,

    CONSTRAINT pk_product_bundles
        PRIMARY KEY (bundle_product_id, child_product_id),

    CONSTRAINT fk_bundle_parent
        FOREIGN KEY (bundle_product_id) REFERENCES products(id),

    CONSTRAINT fk_bundle_child
        FOREIGN KEY (child_product_id) REFERENCES products(id)
);

-- =========================================================
-- INVENTORY (CURRENT STATE)
-- One row per product per warehouse
-- Composite primary key prevents duplicates
-- Optimized for fast stock reads
-- =========================================================
CREATE TABLE inventory (
    product_id      BIGINT NOT NULL,
    warehouse_id    BIGINT NOT NULL,
    quantity        INT NOT NULL DEFAULT 0,
    updated_at      TIMESTAMP NOT NULL,

    CONSTRAINT pk_inventory
        PRIMARY KEY (product_id, warehouse_id),

    CONSTRAINT fk_inventory_product
        FOREIGN KEY (product_id) REFERENCES products(id),

    CONSTRAINT fk_inventory_warehouse
        FOREIGN KEY (warehouse_id) REFERENCES warehouses(id)
);

-- =========================================================
-- INVENTORY MOVEMENTS (AUDIT TRAIL)
-- Stores every inventory change
-- Append-only table for safety and traceability
-- =========================================================
CREATE TABLE inventory_movements (
    id              BIGINT PRIMARY KEY,
    product_id      BIGINT NOT NULL,
    warehouse_id    BIGINT NOT NULL,
    change_qty      INT NOT NULL,
    reason          VARCHAR(50),
    created_at      TIMESTAMP NOT NULL,

    CONSTRAINT fk_movement_product
        FOREIGN KEY (product_id) REFERENCES products(id),

    CONSTRAINT fk_movement_warehouse
        FOREIGN KEY (warehouse_id) REFERENCES warehouses(id)
);

-- =========================================================
-- SUPPLIERS
-- Represents vendors who supply products
-- =========================================================
CREATE TABLE suppliers (
    id              BIGINT PRIMARY KEY,
    name            VARCHAR(255) NOT NULL,
    contact_info    TEXT,
    created_at      TIMESTAMP NOT NULL
);

-- =========================================================
-- SUPPLIER - PRODUCT MAPPING
-- Many suppliers can supply many products
-- Stores supplier-specific metadata
-- =========================================================
CREATE TABLE supplier_products (
    supplier_id     BIGINT NOT NULL,
    product_id      BIGINT NOT NULL,
    cost_price      DECIMAL(10,2),
    lead_time_days  INT,

    CONSTRAINT pk_supplier_products
        PRIMARY KEY (supplier_id, product_id),

    CONSTRAINT fk_supplier_product_supplier
        FOREIGN KEY (supplier_id) REFERENCES suppliers(id),

    CONSTRAINT fk_supplier_product_product
        FOREIGN KEY (product_id) REFERENCES products(id)
);

-- =========================================================
-- RECOMMENDED INDEXES (PERFORMANCE)
-- =========================================================
CREATE INDEX idx_inventory_product
    ON inventory(product_id);

CREATE INDEX idx_inventory_warehouse
    ON inventory(warehouse_id);

CREATE INDEX idx_inventory_movements_created
    ON inventory_movements(created_at);
