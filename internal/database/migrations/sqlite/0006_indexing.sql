-- +goose Up
-- +goose StatementBegin 


CREATE INDEX IF NOT EXISTS idx_ueberweisung_ausschuss ON ueberweisung(ausschuss);
Create INDEX IF NOT EXISTS idx_ueberweisung_ueberweisungsart ON ueberweisung(ueberweisungsart);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin 

DROP INDEX IF EXISTS idx_ueberweisung_ausschuss;
DROP INDEX IF EXISTS idx_ueberweisung_ueberweisungsart;
-- +goose StatementEnd