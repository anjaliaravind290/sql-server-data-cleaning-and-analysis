-- =========================================
-- PortfolioProject Demo SQL (Ready to Run)
-- =========================================

-- STEP 1: Use Database
USE PortfolioProject;
GO

-- =========================================
-- STEP 2: Create Sample Tables
-- =========================================

-- 2.1 NashvilleHousing Table
IF OBJECT_ID('dbo.NashvilliHousing', 'U') IS NOT NULL
    DROP TABLE dbo.NashvilliHousing;
GO

CREATE TABLE NashvilliHousing (
    UniqueID INT IDENTITY(1,1) PRIMARY KEY,
    ParcelID INT,
    PropertyAddress NVARCHAR(255),
    OwnerAddress NVARCHAR(255),
    SaleDate NVARCHAR(50),
    SalePrice DECIMAL(18,2),
    SoldAsVacant CHAR(1),
    LegalReference NVARCHAR(255),
    TaxDistrict NVARCHAR(50)
);
GO

INSERT INTO NashvilliHousing (ParcelID, PropertyAddress, OwnerAddress, SaleDate, SalePrice, SoldAsVacant, LegalReference, TaxDistrict)
VALUES
(101, '123 Main St, Nashville, TN', 'John Doe, Nashville, TN', '2023-01-15', 250000, 'Y', 'LR123', 'TD1'),
(102, NULL, 'Jane Smith, Nashville, TN', '2023-02-20', 320000, 'N', 'LR124', 'TD2'),
(103, '456 Oak St, Nashville, TN', NULL, '2023-03-05', 275000, 'Y', 'LR125', 'TD1'),
(101, NULL, 'John Doe, Nashville, TN', '2023-01-15', 250000, 'Y', 'LR123', 'TD1'),
(104, '789 Pine St, Nashville, TN', 'Alice Brown, Nashville, TN', '2023-04-10', 310000, 'N', 'LR126', 'TD2');
GO

-- 2.2 CovidDeaths Table
IF OBJECT_ID('dbo.CovidDeaths', 'U') IS NOT NULL
    DROP TABLE dbo.CovidDeaths;
GO

CREATE TABLE CovidDeaths (
    location NVARCHAR(100),
    continent NVARCHAR(50),
    date DATE,
    total_cases INT,
    new_cases INT,
    total_deaths INT,
    new_deaths INT,
    population BIGINT
);
GO

INSERT INTO CovidDeaths (location, continent, date, total_cases, new_cases, total_deaths, new_deaths, population)
VALUES
('USA', 'North America', '2020-03-01', 100, 20, 5, 1, 331000000),
('USA', 'North America', '2020-03-02', 150, 50, 8, 3, 331000000),
('India', 'Asia', '2020-03-01', 50, 10, 1, 0, 1380000000),
('India', 'Asia', '2020-03-02', 70, 20, 2, 1, 1380000000),
('Brazil', 'South America', '2020-03-01', 30, 5, 0, 0, 212000000);
GO

-- 2.3 CovidVaccinations Table
IF OBJECT_ID('dbo.CovidVaccinations', 'U') IS NOT NULL
    DROP TABLE dbo.CovidVaccinations;
GO

CREATE TABLE CovidVaccinations (
    location NVARCHAR(100),
    date DATE,
    new_vaccinations INT
);
GO

INSERT INTO CovidVaccinations (location, date, new_vaccinations)
VALUES
('USA', '2020-03-01', 0),
('USA', '2020-03-02', 1000),
('India', '2020-03-01', 0),
('India', '2020-03-02', 500),
('Brazil', '2020-03-01', 0);
GO

-- =========================================
-- STEP 3: NashvilleHousing Data Cleaning
-- =========================================

-- Standardize SaleDate
ALTER TABLE NashvilliHousing ADD SaleDateConverted DATE;
UPDATE NashvilliHousing SET SaleDateConverted = CONVERT(DATE, SaleDate);

-- Populate PropertyAddress from duplicates
UPDATE a
SET a.PropertyAddress = ISNULL(a.PropertyAddress, b.PropertyAddress)
FROM NashvilliHousing a
JOIN NashvilliHousing b
  ON a.ParcelID = b.ParcelID
 AND a.UniqueID <> b.UniqueID
WHERE a.PropertyAddress IS NULL;

-- Split PropertyAddress into Address and City
ALTER TABLE NashvilliHousing ADD PropertySplitAddress NVARCHAR(255);
ALTER TABLE NashvilliHousing ADD PropertySplitCity NVARCHAR(255);
UPDATE NashvilliHousing
SET PropertySplitAddress = SUBSTRING(PropertyAddress,1,CHARINDEX(',',PropertyAddress)-1),
    PropertySplitCity = SUBSTRING(PropertyAddress,CHARINDEX(',',PropertyAddress)+2,LEN(PropertyAddress));

-- Split OwnerAddress
ALTER TABLE NashvilliHousing ADD OwnerSplitAddress NVARCHAR(255);
ALTER TABLE NashvilliHousing ADD OwnerSplitCity NVARCHAR(255);
ALTER TABLE NashvilliHousing ADD OwnerSplitState NVARCHAR(255);
UPDATE NashvilliHousing
SET OwnerSplitAddress = PARSENAME(REPLACE(OwnerAddress,',','.'),3),
    OwnerSplitCity = PARSENAME(REPLACE(OwnerAddress,',','.'),2),
    OwnerSplitState = PARSENAME(REPLACE(OwnerAddress,',','.'),1);

-- Convert SoldAsVacant Y/N to Yes/No
UPDATE NashvilliHousing
SET SoldAsVacant = CASE
    WHEN SoldAsVacant='Y' THEN 'Yes'
    WHEN SoldAsVacant='N' THEN 'No'
    ELSE SoldAsVacant
END;

-- Remove duplicates
WITH RowNumCTE AS (
    SELECT *, ROW_NUMBER() OVER(PARTITION BY ParcelID, PropertyAddress, SalePrice, SaleDate, LegalReference ORDER BY UniqueID) AS row_num
    FROM NashvilliHousing
)
DELETE FROM RowNumCTE WHERE row_num > 1;

-- Drop unused columns
ALTER TABLE NashvilliHousing DROP COLUMN OwnerAddress, TaxDistrict, PropertyAddress, SaleDate;
GO

-- =========================================
-- STEP 4: Covid Data Exploration
-- =========================================

-- Total Cases vs Deaths
SELECT location, date, total_cases, total_deaths, (total_deaths*100.0/total_cases) AS DeathPercentage
FROM CovidDeaths
WHERE continent IS NOT NULL
ORDER BY location, date;

-- Total Cases vs Population
SELECT location, date, population, total_cases, (total_cases*100.0/population) AS PercentPopulationInfected
FROM CovidDeaths
WHERE continent IS NOT NULL
ORDER BY location, date;

-- Countries with highest infection rate
SELECT location, population, MAX(total_cases) AS HighestInfectionCount,
       MAX((total_cases*100.0/population)) AS PercentPopulationInfected
FROM CovidDeaths
WHERE continent IS NOT NULL
GROUP BY location, population
ORDER BY PercentPopulationInfected DESC;

-- Total Deaths per Continent
SELECT continent, MAX(total_deaths) AS TotalDeathCount
FROM CovidDeaths
WHERE continent IS NOT NULL
GROUP BY continent
ORDER BY TotalDeathCount DESC;

-- Total Population vs Vaccinations (Window Function)
WITH PopvsVac AS (
    SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations,
           SUM(CONVERT(INT, vac.new_vaccinations)) OVER (PARTITION BY dea.location ORDER BY dea.date) AS RollingPeopleVaccinated
    FROM CovidDeaths dea
    JOIN CovidVaccinations vac
      ON dea.location = vac.location AND dea.date = vac.date
    WHERE dea.continent IS NOT NULL
)
SELECT *, (RollingPeopleVaccinated*100.0/population) AS PercentPopulationVaccinated
FROM PopvsVac;
GO

-- Temp Table Version
DROP TABLE IF EXISTS #PercentPopulationVaccinated;
CREATE TABLE #PercentPopulationVaccinated (
    Continent NVARCHAR(255),
    Location NVARCHAR(255),
    Date DATE,
    Population NUMERIC,
    New_vaccinations NUMERIC,
    RollingPeopleVaccinated NUMERIC
);
INSERT INTO #PercentPopulationVaccinated
SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations,
       SUM(CONVERT(INT, vac.new_vaccinations)) OVER (PARTITION BY dea.location ORDER BY dea.date) AS RollingPeopleVaccinated
FROM CovidDeaths dea
JOIN CovidVaccinations vac
  ON dea.location = vac.location AND dea.date = vac.date;
SELECT *, (RollingPeopleVaccinated*100.0/population) AS PercentPopulationVaccinated
FROM #PercentPopulationVaccinated;
GO

-- Creating a View for Later Visualizations
CREATE OR ALTER VIEW PercentPopulationVaccinated AS
SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations,
       SUM(CONVERT(INT, vac.new_vaccinations)) OVER (PARTITION BY dea.location ORDER BY dea.date) AS RollingPeopleVaccinated
FROM CovidDeaths dea
JOIN CovidVaccinations vac
  ON dea.location = vac.location AND dea.date = vac.date
WHERE dea.continent IS NOT NULL;
GO
