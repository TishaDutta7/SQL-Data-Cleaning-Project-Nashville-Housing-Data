/********************************************************************************************
   STEP 1 — VIEW RAW DATA
*********************************************************************************************/
SELECT *
FROM NashvilleHousing;



/********************************************************************************************
   STEP 2 — STANDARDIZE DATE FORMAT
   In MySQL we convert using DATE() function.
   If SaleDate column is not already DATE type, create a new one.
*********************************************************************************************/

-- Add new converted column
ALTER TABLE NashvilleHousing
ADD COLUMN SaleDateConverted DATE;

-- Populate it
UPDATE NashvilleHousing
SET SaleDateConverted = DATE(SaleDate);



/********************************************************************************************
   STEP 3 — POPULATE MISSING PROPERTY ADDRESSES USING SELF JOIN
*********************************************************************************************/

UPDATE NashvilleHousing a
JOIN NashvilleHousing b
    ON a.ParcelID = b.ParcelID
   AND a.UniqueID <> b.UniqueID
SET a.PropertyAddress = b.PropertyAddress
WHERE a.PropertyAddress IS NULL;



/********************************************************************************************
   STEP 4 — SPLIT PROPERTY ADDRESS INTO Address + City
   Format is "Address, City"
   MySQL uses SUBSTRING_INDEX() for splitting.
*********************************************************************************************/

-- Add new columns
ALTER TABLE NashvilleHousing
ADD COLUMN PropertySplitAddress VARCHAR(255),
ADD COLUMN PropertySplitCity VARCHAR(255);

-- Populate split address
UPDATE NashvilleHousing
SET PropertySplitAddress = SUBSTRING_INDEX(PropertyAddress, ',', 1),
    PropertySplitCity    = TRIM(SUBSTRING_INDEX(PropertyAddress, ',', -1))
WHERE PropertyAddress LIKE '%,%';



/********************************************************************************************
   STEP 5 — SPLIT OWNER ADDRESS INTO Address, City, State
   Format: "Address, City, State"
   Using SUBSTRING_INDEX() and nested splits.
*********************************************************************************************/

ALTER TABLE NashvilleHousing
ADD COLUMN OwnerSplitAddress VARCHAR(255),
ADD COLUMN OwnerSplitCity VARCHAR(255),
ADD COLUMN OwnerSplitState VARCHAR(255);

-- Populate split fields
UPDATE NashvilleHousing
SET OwnerSplitAddress = SUBSTRING_INDEX(OwnerAddress, ',', 1),
    OwnerSplitCity    = TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(OwnerAddress, ',', 2), ',', -1)),
    OwnerSplitState   = TRIM(SUBSTRING_INDEX(OwnerAddress, ',', -1));



/********************************************************************************************
   STEP 6 — STANDARDIZE SoldAsVacant (Y / N → Yes / No)
*********************************************************************************************/

UPDATE NashvilleHousing
SET SoldAsVacant = 
    CASE
        WHEN SoldAsVacant = 'Y' THEN 'Yes'
        WHEN SoldAsVacant = 'N' THEN 'No'
        ELSE SoldAsVacant
    END;



/********************************************************************************************
   STEP 7 — REMOVE DUPLICATES USING ROW_NUMBER() (MySQL 8+)
   Keeping only the first occurrence.
*********************************************************************************************/

WITH RowNumCTE AS (
    SELECT 
        UniqueID,
        ROW_NUMBER() OVER (
            PARTITION BY ParcelID, PropertyAddress, SalePrice, SaleDateConverted, LegalReference
            ORDER BY UniqueID
        ) AS row_num
    FROM NashvilleHousing
)
DELETE FROM NashvilleHousing
WHERE UniqueID IN (
    SELECT UniqueID
    FROM (
        SELECT UniqueID
        FROM RowNumCTE
        WHERE row_num > 1
    ) AS temp
);



/********************************************************************************************
   STEP 8 — DELETE UNUSED COLUMNS
*********************************************************************************************/

ALTER TABLE NashvilleHousing
DROP COLUMN OwnerAddress,
DROP COLUMN TaxDistrict,
DROP COLUMN PropertyAddress,
DROP COLUMN SaleDate;
