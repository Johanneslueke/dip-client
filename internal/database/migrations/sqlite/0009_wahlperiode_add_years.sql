-- +goose Up
-- +goose StatementBegin

-- Add start_year and end_year columns to wahlperiode table
-- =========================================================
-- Purpose: Track temporal boundaries of each Wahlperiode for time-based analysis
-- Data scope: WP7-21 (database contains vorgänge from these periods only)
--
-- Historical context:
--   - Standard term: 4 years
--   - Shortened terms: WP6 (Vertrauensfrage 1972), WP9 (Vertrauensfrage 1983), 
--                      WP11 (Wiedervereinigung 1990), WP15 (Vertrauensfrage 2005),
--                      WP20 (Vertrauensfrage 2024)
--   - WP21 end year projected based on 2025 election
--
-- Source: https://de.wikipedia.org/wiki/Deutscher_Bundestag#Wahlperioden_des_Deutschen_Bundestages
--   WP7:  13. Dezember 1972 – 13. Dezember 1976
--   WP8:  14. Dezember 1976 – 4. November 1980
--   WP9:  4. November 1980 – 29. März 1983 (shortened)
--   WP10: 29. März 1983 – 18. Februar 1987
--   WP11: 18. Februar 1987 – 20. Dezember 1990 (shortened)
--   WP12: 20. Dezember 1990 – 10. November 1994
--   WP13: 10. November 1994 – 26. Oktober 1998
--   WP14: 26. Oktober 1998 – 17. Oktober 2002
--   WP15: 17. Oktober 2002 – 18. Oktober 2005 (shortened)
--   WP16: 18. Oktober 2005 – 27. Oktober 2009
--   WP17: 27. Oktober 2009 – 22. Oktober 2013
--   WP18: 22. Oktober 2013 – 24. Oktober 2017
--   WP19: 24. Oktober 2017 – 26. Oktober 2021
--   WP20: 26. Oktober 2021 – 25. März 2025 (shortened)
--   WP21: seit 25. März 2025 (projected end: 2029)

ALTER TABLE wahlperiode ADD COLUMN start_year INTEGER;
ALTER TABLE wahlperiode ADD COLUMN end_year INTEGER;

-- Populate historical data for WP7-21 (database scope)
UPDATE wahlperiode SET start_year = 1972, end_year = 1976 WHERE nummer = 7;
UPDATE wahlperiode SET start_year = 1976, end_year = 1980 WHERE nummer = 8;
UPDATE wahlperiode SET start_year = 1980, end_year = 1983 WHERE nummer = 9;
UPDATE wahlperiode SET start_year = 1983, end_year = 1987 WHERE nummer = 10;
UPDATE wahlperiode SET start_year = 1987, end_year = 1990 WHERE nummer = 11;
UPDATE wahlperiode SET start_year = 1990, end_year = 1994 WHERE nummer = 12;
UPDATE wahlperiode SET start_year = 1994, end_year = 1998 WHERE nummer = 13;
UPDATE wahlperiode SET start_year = 1998, end_year = 2002 WHERE nummer = 14;
UPDATE wahlperiode SET start_year = 2002, end_year = 2005 WHERE nummer = 15;
UPDATE wahlperiode SET start_year = 2005, end_year = 2009 WHERE nummer = 16;
UPDATE wahlperiode SET start_year = 2009, end_year = 2013 WHERE nummer = 17;
UPDATE wahlperiode SET start_year = 2013, end_year = 2017 WHERE nummer = 18;
UPDATE wahlperiode SET start_year = 2017, end_year = 2021 WHERE nummer = 19;
UPDATE wahlperiode SET start_year = 2021, end_year = 2025 WHERE nummer = 20;
UPDATE wahlperiode SET start_year = 2025, end_year = 2029 WHERE nummer = 21;

-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin

-- Remove the columns
ALTER TABLE wahlperiode DROP COLUMN start_year;
ALTER TABLE wahlperiode DROP COLUMN end_year;

-- +goose StatementEnd
