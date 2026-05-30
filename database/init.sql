-- Financial Enterprise Application - reference schema (Alembic is source of truth in prod)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

COMMENT ON DATABASE fin_enterprise_assets IS 'Financial Enterprise institutional portfolio and holdings data';
