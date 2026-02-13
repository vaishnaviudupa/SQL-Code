USE world_layoffs;
SELECT * FROM layoffs;

-- 1. Remove Duplicates
-- 2. Standardize the data
-- 3. Null/blank Values
-- 4. Remove any Columns

-- Create a Staging table, so that even if we have a mistake while updating the table, we still would have the original table
CREATE TABLE layoffs_staging
LIKE layoffs;

INSERT layoffs_staging
SELECT *
FROM layoffs;

SELECT * FROM layoffs_staging;

-- To check for Duplicates, using Row_Number. If value>1, then its a duplicate
SELECT *,
ROW_NUMBER() OVER(
PARTITION BY company, industry, total_laid_off, percentage_laid_off, `date`) AS row_num
FROM layoffs_staging;

-- Using CTE to check for values>1
WITH duplicate_cte AS
(
SELECT *,
ROW_NUMBER() OVER(
PARTITION BY company, location, industry, total_laid_off, percentage_laid_off, `date`, stage, country, funds_raised_millions) AS row_num
FROM layoffs_staging
)
SELECT * 
FROM duplicate_cte
WHERE row_num>1;

SELECT * FROM layoffs_staging
WHERE company= 'Casper';  -- Here we have 2 duplicates and not 3. So, we need to delete just 1 of them.alter

-- But if we try to delete it (as part of CTE), it wont allow. As, we can't update the CTE.
-- So, what we do is, we create a staging2 table and dletee from there.alter

CREATE TABLE `layoffs_staging2` (
  `company` text,
  `location` text,
  `industry` text,
  `total_laid_off` int DEFAULT NULL,
  `percentage_laid_off` text,
  `date` text,
  `stage` text,
  `country` text,
  `funds_raised_millions` int DEFAULT NULL,
  `row_num` INT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO layoffs_staging2
SELECT *,
ROW_NUMBER() OVER(
PARTITION BY company, location, industry, total_laid_off, percentage_laid_off, `date`, stage, country, funds_raised_millions) AS row_num
FROM layoffs_staging;

SELECT * FROM layoffs_staging2;
SELECT * FROM layoffs_staging2 WHERE row_num>1;
DELETE FROM layoffs_staging2 WHERE row_num>1;

-- STANDARDIZING DATA  (Finding issues in data & thenn fixing it)
SELECT company,TRIM(company)
FROM layoffs_staging2;    -- ( E Inc.->E Inc.)

UPDATE layoffs_staging2
SET company=TRIM(company);

SELECT DISTINCT industry
FROM layoffs_staging2 ORDER BY 1;   
-- (To remove repetitive industries like Crypto
-- Crypto Currency
-- CryptoCurrency)

SELECT * FROM layoffs_staging2 WHERE industry like 'Crypto%';

UPDATE layoffs_staging2
SET industry='Crypto'
WHERE industry like 'Crypto%';

-- Go thru every column & see if there's any issue
SELECT DISTINCT country
FROM layoffs_staging2 ORDER BY 1;  

-- Issues like->
-- United States, 
-- United States.

SELECT DISTINCT country, TRIM(TRAILING '.' FROM country)
FROM layoffs_staging2 ORDER BY 2;

UPDATE layoffs_staging2
SET COUNTRY=TRIM(TRAILING '.' FROM country)
WHERE country like 'United States%';

-- Changing from text to date column
SELECT `date`,
str_to_date(`date`, '%m/%d/%Y')
FROM layoffs_staging2;

UPDATE layoffs_staging2
SET `date`=str_to_date(`date`, '%m/%d/%Y');  -- Doing this doesn't change the data type of the column to Date.
-- You still have to alter the table

ALTER TABLE layoffs_staging2
MODIFY COLUMN `date` DATE;

-- Handling Null/Blank values
SELECT * FROM layoffs_staging2 
WHERE industry IS NULL OR industry= '';  

SELECT * 
FROM layoffs_staging2 t1
JOIN layoffs_staging2 t2
	ON t1.company=t2.company
WHERE (t1.industry IS NULL OR t1.industry= '')
AND t2.industry IS NOT NULL; 

UPDATE layoffs_staging2 SET industry= NULL
WHERE industry='';

UPDATE layoffs_staging2 t1
JOIN layoffs_staging2 t2
	ON t1.company=t2.company
SET t1.industry=t2.industry
WHERE t1.industry IS NULL
AND t2.industry IS NOT NULL; 

SELECT * FROM layoffs_staging2 
WHERE total_laid_off IS NULL
AND percentage_laid_off IS NULL;

-- Here we are deleting the records. But, its not advisable to do so. Only do it if youre 200% sure
DELETE 
FROM layoffs_staging2 
WHERE total_laid_off IS NULL
AND percentage_laid_off IS NULL;

-- Since we dont need row_num anymore
ALTER TABLE layoffs_staging2
DROP COLUMN row_num;