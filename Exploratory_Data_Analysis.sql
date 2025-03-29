-- Exploratory Data Analysis 
-- use the cleaned up data to get insights
SELECT *
FROM layoffs_staging2;

-- looking into details of the data
SELECT MAX(total_laid_off), MAX(percentage_laid_off)
FROM layoffs_staging2;

SELECT *
FROM layoffs_staging2
WHERE percentage_laid_off = 1
ORDER BY total_laid_off DESC;

SELECT *
FROM layoffs_staging2
WHERE percentage_laid_off = 1
ORDER BY funds_raised_millions DESC;

-- looking at company
SELECT company, SUM(total_laid_off)
FROM layoffs_staging2
GROUP BY company
ORDER BY 2 DESC;

SELECT MIN(`date`), MAX(`date`)
FROM layoffs_staging2;

-- looking at industry
SELECT industry, SUM(total_laid_off)
FROM layoffs_staging2
GROUP BY industry
ORDER BY 2 DESC;

SELECT *
FROM layoffs_staging2;

-- looking at country
SELECT country, SUM(total_laid_off)
FROM layoffs_staging2
GROUP BY country
ORDER BY 2 DESC;

-- by date (year)
SELECT YEAR(`date`), SUM(total_laid_off)
FROM layoffs_staging2
GROUP BY YEAR(`date`)
ORDER BY 1 DESC;

-- looking at stage
SELECT stage, SUM(total_laid_off)
FROM layoffs_staging2
GROUP BY stage
ORDER BY 2 DESC;

-- looking at percentages (doesn't seem as relevant after looking)
SELECT company, SUM(percentage_laid_off)
FROM layoffs_staging2
GROUP BY company
ORDER BY 2 DESC;

-- looking at progression of layoff (rolling sum)
-- by year/month
SELECT SUBSTRING(`date`,1,7) AS `MONTH`, SUM(total_laid_off)
FROM layoffs_staging2
WHERE SUBSTRING(`date`,1,7) IS NOT NULL
GROUP BY `MONTH`
ORDER BY 1 ASC
;

-- month by month progression of layoffs
WITH Rolling_Total AS
(
SELECT SUBSTRING(`date`,1,7) AS `MONTH`, SUM(total_laid_off) AS total_off
FROM layoffs_staging2
WHERE SUBSTRING(`date`,1,7) IS NOT NULL
GROUP BY `MONTH`
ORDER BY 1 ASC
)
SELECT `MONTH`, total_off,
	SUM(total_off) OVER(
		ORDER BY 'MONTH'
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
	) AS rolling_total
FROM Rolling_Total;

-- looking at company laying off per year
SELECT company, SUM(total_laid_off)
FROM layoffs_staging2
GROUP BY company
ORDER BY 2 DESC;

SELECT company, YEAR(`date`), SUM(total_laid_off)
FROM layoffs_staging2
GROUP BY company, YEAR(`date`)
ORDER BY 3 DESC;

-- rank them ( top 5 who laid off the most people per year)
WITH Company_Year (company, years, total_laid_off) AS
(
SELECT company, YEAR(`date`), SUM(total_laid_off)
FROM layoffs_staging2
GROUP BY company, YEAR(`date`)
), Company_Year_Rank AS
(SELECT *,
DENSE_RANK() OVER (PARTITION BY years ORDER BY total_laid_off DESC) AS Ranking
FROM Company_Year
WHERE years IS NOT NULL
)
SELECT *
FROM Company_Year_Rank
WHERE Ranking <= 5;

-- find total of people before layoff
SELECT *
FROM layoffs_staging2;

SELECT *
FROM layoffs_staging2
WHERE percentage_laid_off = 0;

WITH Total_Before_Layoff AS
(
SELECT company,
	location,
    industry,
    total_laid_off,
    percentage_laid_off,
    CASE
		WHEN total_laid_off IS NOT NULL
			AND percentage_laid_OFF IS NOT NULL
            AND percentage_laid_off != 0
		THEN ROUND(total_laid_off / percentage_laid_off,2)
	END AS total_before_layoff,
    `date`,
    stage,
    country,
    funds_raised_millions
FROM layoffs_staging2
)
SELECT *
FROM Total_Before_Layoff;

CREATE TABLE `layoffs_staging3` (
  `company` text,
  `location` text,
  `industry` text,
  `total_laid_off` int DEFAULT NULL,
  `percentage_laid_off` text,
  `total_before_layoff` INT,
  `date` date DEFAULT NULL,
  `stage` text,
  `country` text,
  `funds_raised_millions` int DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- new table made that includes total of people before layoff! yay!

SELECT *
FROM layoffs_staging3;

INSERT INTO layoffs_staging3
SELECT company,
	location,
    industry,
    total_laid_off,
    percentage_laid_off,
    CASE
		WHEN total_laid_off IS NOT NULL
			AND percentage_laid_OFF IS NOT NULL
            AND percentage_laid_off != 0
		THEN ROUND(total_laid_off / percentage_laid_off,2)
	END AS total_before_layoff,
    `date`,
    stage,
    country,
    funds_raised_millions
FROM layoffs_staging2;

-- FUNDING EFFICIENCY
-- did companies with more money per person still lay people off (per year)

SELECT *
FROM layoffs_staging3
ORDER BY 1 ASC;

-- finding highest funding per employee each year
SELECT company,
	YEAR(`date`) AS `year`,
    SUM(total_laid_off) AS total_laid_off,
    SUM(total_before_layoff) AS total_before_layoff,
    SUM(funds_raised_millions) AS total_funding_mil,
	ROUND(SUM(funds_raised_millions * 1000000) / sum(total_before_layoff),3) AS funding_per_emp,
    ROUND(SUM(total_laid_off) / SUM(total_before_layoff), 4) AS overall_layoff_ratio
FROM layoffs_staging3
WHERE total_laid_off IS NOT NULL
	AND percentage_laid_off IS NOT NULL
    AND total_before_layoff IS NOT NULL
    AND funds_raised_millions IS NOT NULL
    AND percentage_laid_off != 0
    AND percentage_laid_off !=0
GROUP BY company, YEAR(`date`)
ORDER BY funding_per_emp DESC;

-- CTE to refer to
CREATE TEMPORARY Table temp_company_year_summary
(
SELECT company,
	YEAR(`date`) AS `year`,
    SUM(total_laid_off) AS total_laid_off,
    SUM(total_before_layoff) AS total_before_layoff,
    SUM(funds_raised_millions) AS total_funding_mil,
	ROUND(SUM(funds_raised_millions) / sum(total_before_layoff),3) AS funding_per_emp,
    ROUND(SUM(total_laid_off) / SUM(total_before_layoff), 4) AS overall_layoff_ratio
FROM layoffs_staging3
WHERE total_laid_off IS NOT NULL
	AND percentage_laid_off IS NOT NULL
    AND total_before_layoff IS NOT NULL
    AND funds_raised_millions IS NOT NULL
    AND percentage_laid_off != 0
    AND percentage_laid_off !=0
GROUP BY company, YEAR(`date`)
);

SELECT *
FROM temp_company_year_summary;

SELECT *
FROM temp_company_year_summary
WHERE overall_layoff_ratio > 0.3;

SELECT *
FROM temp_company_year_summary
ORDER BY total_funding_mil DESC LIMIT 10;

-- rank funding per employee
SELECT *,
	RANK() OVER (PARTITION BY `year` ORDER BY funding_per_emp DESC) AS funding_eff_rank
FROM temp_company_year_summary;

-- find top 5 by funding efficiency per year
WITH ranked_funding AS
(
SELECT *,
	RANK() OVER (PARTITION BY `year` ORDER BY funding_per_emp DESC) AS funding_eff_rank
FROM temp_company_year_summary
)
SELECT *
FROM ranked_funding
WHERE funding_eff_rank <= 5
ORDER BY `year` DESC, funding_eff_rank;

-- rank company per year by layoff ratio
WITH ranked_layoff AS (
	SELECT *,
		DENSE_RANK() OVER (PARTITION BY `year` ORDER BY overall_layoff_ratio DESC) AS layoff_ratio_rank
	FROM temp_company_year_summary
)
SELECT *
FROM ranked_layoff
WHERE layoff_ratio_rank <= 5
ORDER BY `year` DESC, layoff_ratio_rank;

-- compare high fund with high layoff ratios
SELECT *
FROM temp_company_year_summary
WHERE funding_per_emp > 300000
	AND overall_layoff_ratio > 0.5
ORDER BY funding_per_emp DESC;


-- compare year over year trends
SELECT `year`,
	ROUND(AVG(overall_layoff_ratio), 4) AS avg_layoff_ratio,
    ROUND(AVG(funding_per_emp), 2) AS avg_funding_per_emp
FROM temp_company_year_summary
GROUP BY `year`
ORDER BY `year`;