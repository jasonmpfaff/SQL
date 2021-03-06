-- =============================================================================================
--	Intended to run every week
-- =============================================================================================
IF OBJECT_ID('tempdb..#Starts') IS NOT NULL	DROP TABLE #Starts

CREATE TABLE #Starts (StartDate DATETIME, StartYear INT, StartNumber SMALLINT)
CREATE NONCLUSTERED INDEX NDX_Starts ON #Starts (StartDate)

IF OBJECT_ID('tempdb..#StartsPY') IS NOT NULL	DROP TABLE #StartsPY
CREATE TABLE #StartsPY(StartDate DATETIME, StartYear INT, StartNumber SMALLINT)
CREATE NONCLUSTERED INDEX NDX_StartsPY ON #StartsPY (StartDate)

INSERT INTO #Starts(StartDate, StartYear, StartNumber)
	SELECT TOP 5 
		StartDate, StartYear, StartNumber
	FROM 
		CVCustomReporting.dbo.Starts
	WHERE 
		DATEADD(dd, 28, StartDate) < GETDATE()
	ORDER BY
		StartDate DESC


INSERT INTO #StartsPY(StartDate, StartYear, StartNumber)
	SELECT TOP 5
		st.StartDate, st.StartYear, st.StartNumber
	FROM 
		#Starts s
		INNER JOIN CVCustomReporting.dbo.Starts st ON st.StartYear = s.StartYear - 1 AND st.StartNumber = s.StartNumber
	ORDER BY
		st.StartDate DESC

--select * from #Starts
--select * from #PriorYrStarts

-- =============================================================================================
-- Pull Current Start Students
-- =============================================================================================
IF OBJECT_ID('tempdb..#Past4TermStarts') IS NOT NULL DROP TABLE #Past4TermStarts

CREATE TABLE #Past4TermStarts (StartDate DATETIME, StartPeriod VARCHAR(50), StartYear INT, StartNumber SMALLINT, SyCampusID INT, SyStudentID INT, 
	AdEnrollID INT, IsNetStart INT, IsNetReEntry INT, IsDrop INT, DropDate DATETIME)
CREATE NONCLUSTERED INDEX NDX_Past4TermStarts ON #Past4TermStarts (StartDate)

INSERT INTO #Past4TermStarts (StartDate, StartPeriod, StartYear, StartNumber, SyCampusID, SyStudentID, AdEnrollID, IsNetStart, IsNetReEntry, IsDrop, DropDate)
SELECT
	strt.StartDate,
	strt.StartPeriod,
	st.StartYear,
	st.StartNumber,
	strt.SyCampusID,
	strt.SyStudentID,
	strt.AdEnrollID,
	strt.IsNetStart,
	strt.IsNetReEntry,
	IsDrop = CASE WHEN (MIN(ssc.SyStatChangeID) IS NOT NULL) THEN 1 ELSE 0 END,
	DropDate = MIN(ssc.EffectiveDate)
	
	--strt.NumNetStart,
	--strt.NumNetReEntry
FROM 
	CVCustomReporting.dbo.AdmissionsStart_Detail strt
	INNER JOIN #Starts st ON st.StartDate = strt.StartDate
	LEFT OUTER JOIN CampusVue.dbo.SyStatChange ssc WITH(NOLOCK) ON ssc.AdEnrollID = strt.AdEnrollID 
								AND ssc.NewSySchoolStatusID IN (20, 61) AND ssc.EffectiveDate > strt.StartDate
WHERE
	strt.MostRecent = 1
	AND strt.IsIncoming = 1
	AND strt.IsDupe = 0
GROUP BY
	strt.StartDate,
	strt.StartPeriod,
	st.StartYear,
	st.StartNumber,
	strt.SyCampusID,
	strt.SyStudentID,
	strt.AdEnrollID,
	strt.IsNetStart,
	strt.IsNetReEntry,
	strt.IsDrop,
	strt.IsCurrentLogic

-- =============================================================================================
-- Pull PY Start Students
-- =============================================================================================
IF OBJECT_ID('tempdb..#Past4TermStartsPY') IS NOT NULL DROP TABLE #Past4TermStartsPY

CREATE TABLE #Past4TermStartsPY (StartDate DATETIME, StartPeriod VARCHAR(50), StartYear INT, StartNumber SMALLINT, SyCampusID INT, SyStudentID INT, 
		AdEnrollID INT, IsNetStart INT, IsNetReEntry INT, IsDrop INT, DropDate DATETIME)
CREATE NONCLUSTERED INDEX NDX_Past4TermStartsPY ON #Past4TermStartsPY (StartDate)

INSERT INTO #Past4TermStartsPY (StartDate, StartPeriod, StartYear, StartNumber, SyCampusID, SyStudentID, AdEnrollID, IsNetStart, IsNetReEntry, IsDrop, DropDate)
SELECT
	strt.StartDate,
	strt.StartPeriod,
	st.StartYear,
	st.StartNumber,
	strt.SyCampusID,
	strt.SyStudentID,
	strt.AdEnrollID,
	strt.IsNetStart,
	strt.IsNetReEntry,
	IsDrop = CASE WHEN (MIN(ssc.SyStatChangeID) IS NOT NULL) THEN 1 ELSE 0 END,
	DropDate = MIN(ssc.EffectiveDate)
	--strt.NumNetStart,
	--strt.NumNetReEntry
FROM 
	CVCustomReporting.dbo.AdmissionsStart_Detail strt
	INNER JOIN #StartsPY st ON st.StartDate = strt.StartDate
	LEFT OUTER JOIN CampusVue.dbo.SyStatChange ssc WITH(NOLOCK) ON ssc.AdEnrollID = strt.AdEnrollID 
								AND ssc.NewSySchoolStatusID IN (20, 61) AND ssc.EffectiveDate > strt.StartDate
WHERE
	strt.MostRecent = 1
	AND strt.IsIncoming = 1
	AND strt.IsDupe = 0
GROUP BY
	strt.StartDate,
	strt.StartPeriod,
	st.StartYear,
	st.StartNumber,
	strt.SyCampusID,
	strt.SyStudentID,
	strt.AdEnrollID,
	strt.IsNetStart,
	strt.IsNetReEntry,
	strt.IsDrop,
	strt.IsCurrentLogic

-- Need to check transfer into enroll record for CTC merged students
-- Get list of 'transferred into' enrollments to check
;WITH CtcNewEnrolls AS 
(
	SELECT 
		tsp.StartDate,
		tsp.SyStudentID,
		ssc.AdEnrollID 
	FROM 
		#Past4TermStartsPY tsp 
		INNER JOIN CampusVue.dbo.SyStatChange ssc WITH(NOLOCK) ON ssc.SyStudentID = tsp.SyStudentID
	WHERE
		tsp.SyCampusID IN (78,79)	-- CTC schools
		AND ssc.PrevSySchoolStatusID = 9
		AND ssc.NewSySchoolStatusID = 13 
		AND ssc.EffectiveDate > tsp.StartDate
)

-- Check for drops in these enrollments
MERGE INTO #Past4TermStartsPY AS dest
USING (
	SELECT
		ne.StartDate,
		ne.SyStudentID,
		DropDate = MIN(ssc.EffectiveDate)
	FROM
		CtcNewEnrolls ne
		INNER JOIN CampusVue.dbo.SyStatChange ssc WITH(NOLOCK) ON ssc.AdEnrollID = ne.AdEnrollID 
								AND ssc.NewSySchoolStatusID IN (20, 61) AND ssc.EffectiveDate > ne.StartDate
	GROUP BY
		ne.StartDate,
		ne.SyStudentID		
		
) AS src ON src.StartDate = dest.StartDate AND src.SyStudentID = dest.SyStudentID
WHEN MATCHED THEN UPDATE SET 
	dest.IsDrop = 1,
	dest.DropDate = src.DropDate;


--select * from #Past4TermStartsPY
IF OBJECT_ID('tempdb..#Past4TermStartsRollup') IS NOT NULL DROP TABLE #Past4TermStartsRollup
IF OBJECT_ID('tempdb..#Past4TermStartsPYRollup') IS NOT NULL DROP TABLE #Past4TermStartsPYRollup

CREATE TABLE #Past4TermStartsRollup(StartDate DATETIME, StartPeriod VARCHAR(50), StartYear INT, StartNumber SMALLINT, SyCampusID INT, 
	NumNetStart INT, NumNetReEntry INT, NumDrop INT, NumWithin180Drop INT, NumProvDrop INT, Num30Drop INT, Num60Drop INT, Num90Drop INT, 
	Num120Drop INT, Num150Drop INT, Num180Drop INT)
	
CREATE NONCLUSTERED INDEX NDX_Past4TermStartsRollup ON #Past4TermStartsRollup (StartYear, StartNumber, SyCampusID)

CREATE TABLE #Past4TermStartsPYRollup(StartDate DATETIME, StartPeriod VARCHAR(50), StartYear INT, StartNumber SMALLINT, SyCampusID INT, 
	NumNetStart INT, NumNetReEntry INT, NumDrop INT, NumWithin180Drop INT, NumProvDrop INT, Num30Drop INT, Num60Drop INT, Num90Drop INT, 
	Num120Drop INT, Num150Drop INT, Num180Drop INT)
	
CREATE NONCLUSTERED INDEX NDX_Past4TermStartsPYRollup ON #Past4TermStartsPYRollup (StartYear, StartNumber, SyCampusID)

;WITH CurrFlagged AS (
	SELECT 
		StartDate,
		StartPeriod,
		StartYear,
		StartNumber,
		SyCampusID,
		SyStudentID,
		AdEnrollID,
		IsNetStart,
		IsNetReEntry,
		IsDrop,
		DropDate,
		IsWithin180Drop = CASE WHEN (DropDate BETWEEN StartDate AND DATEADD(ms, -3, DATEADD(dd, 181, StartDate))) THEN 1 ELSE 0 END,
		IsProvDrop = CASE WHEN (DropDate BETWEEN StartDate AND DATEADD(ms, -3, DATEADD(dd, 29, StartDate))) THEN 1 ELSE 0 END,
		Is30Drop = CASE WHEN (DropDate BETWEEN StartDate AND DATEADD(ms, -3, DATEADD(dd, 31, StartDate))) THEN 1 ELSE 0 END,
		Is60Drop = CASE WHEN (DropDate BETWEEN DATEADD(dd, 31, StartDate) AND DATEADD(ms, -3, DATEADD(dd, 61, StartDate))) THEN 1 ELSE 0 END,
		Is90Drop = CASE WHEN (DropDate BETWEEN DATEADD(dd, 61, StartDate) AND DATEADD(ms, -3, DATEADD(dd, 91, StartDate))) THEN 1 ELSE 0 END,
		Is120Drop = CASE WHEN (DropDate BETWEEN DATEADD(dd, 91, StartDate) AND DATEADD(ms, -3, DATEADD(dd, 121, StartDate))) THEN 1 ELSE 0 END,
		Is150Drop = CASE WHEN (DropDate BETWEEN DATEADD(dd, 121, StartDate) AND DATEADD(ms, -3, DATEADD(dd, 151, StartDate))) THEN 1 ELSE 0 END,
		Is180Drop = CASE WHEN (DropDate BETWEEN DATEADD(dd, 151, StartDate) AND DATEADD(ms, -3, DATEADD(dd, 181, StartDate))) THEN 1 ELSE 0 END
	FROM 
		#Past4TermStarts
)


INSERT INTO #Past4TermStartsRollup (StartDate, StartPeriod, StartYear, StartNumber, SyCampusID, NumNetStart, NumNetReEntry, NumDrop, 
	NumWithin180Drop, NumProvDrop, Num30Drop, Num60Drop, Num90Drop, Num120Drop, Num150Drop, Num180Drop)
SELECT
	StartDate, StartPeriod, StartYear, StartNumber, SyCampusID,
	NumNetStart = SUM(IsNetStart), 
	NumNetReEntry = SUM(IsNetReEntry), 
	NumDrop = SUM(IsDrop), 
	NumWithin180Drop = SUM(IsWithin180Drop),
	NumProvDrop = SUM(IsProvDrop),
	Num30Drop = SUM(Is30Drop), 
	Num60Drop = SUM(Is60Drop), 
	Num90Drop = SUM(Is90Drop), 
	Num120Drop = SUM(Is120Drop), 
	Num150Drop = SUM(Is150Drop),
	Num180Drop = SUM(Is180Drop)
FROM
	CurrFlagged
GROUP BY
	StartDate, StartPeriod, StartYear, StartNumber, SyCampusID, StartYear, StartNumber

;WITH PYFlagged AS (
	SELECT 
		StartDate,
		StartPeriod,
		StartYear,
		StartNumber,
		SyCampusID,
		SyStudentID,
		AdEnrollID,
		IsNetStart,
		IsNetReEntry,
		IsDrop,
		DropDate,
		IsWithin180Drop = CASE WHEN (DropDate BETWEEN StartDate AND DATEADD(ms, -3, DATEADD(dd, 181, StartDate))) THEN 1 ELSE 0 END,
		IsProvDrop = CASE WHEN (DropDate BETWEEN StartDate AND DATEADD(ms, -3, DATEADD(dd, 29, StartDate))) THEN 1 ELSE 0 END,
		Is30Drop = CASE WHEN (DropDate BETWEEN StartDate AND DATEADD(ms, -3, DATEADD(dd, 31, StartDate))) THEN 1 ELSE 0 END,
		Is60Drop = CASE WHEN (DropDate BETWEEN DATEADD(dd, 31, StartDate) AND DATEADD(ms, -3, DATEADD(dd, 61, StartDate))) THEN 1 ELSE 0 END,
		Is90Drop = CASE WHEN (DropDate BETWEEN DATEADD(dd, 61, StartDate) AND DATEADD(ms, -3, DATEADD(dd, 91, StartDate))) THEN 1 ELSE 0 END,
		Is120Drop = CASE WHEN (DropDate BETWEEN DATEADD(dd, 91, StartDate) AND DATEADD(ms, -3, DATEADD(dd, 121, StartDate))) THEN 1 ELSE 0 END,
		Is150Drop = CASE WHEN (DropDate BETWEEN DATEADD(dd, 121, StartDate) AND DATEADD(ms, -3, DATEADD(dd, 151, StartDate))) THEN 1 ELSE 0 END,
		Is180Drop = CASE WHEN (DropDate BETWEEN DATEADD(dd, 151, StartDate) AND DATEADD(ms, -3, DATEADD(dd, 181, StartDate))) THEN 1 ELSE 0 END
		
	FROM 
		#Past4TermStartsPY
)


INSERT INTO #Past4TermStartsPYRollup (StartDate, StartPeriod, StartYear, StartNumber, SyCampusID, NumNetStart, NumNetReEntry, NumDrop, 
	NumWithin180Drop, NumProvDrop, Num30Drop, Num60Drop, Num90Drop, Num120Drop, Num150Drop, Num180Drop)
SELECT
	StartDate, StartPeriod, StartYear, StartNumber, SyCampusID,
	NumNetStart = SUM(IsNetStart), 
	NumNetReEntry = SUM(IsNetReEntry), 
	NumDrop = SUM(IsDrop), 
	NumWithin180Drop = SUM(IsWithin180Drop),
	NumProvDrop = SUM(IsProvDrop),
	Num30Drop = SUM(Is30Drop), 
	Num60Drop = SUM(Is60Drop), 
	Num90Drop = SUM(Is90Drop), 
	Num120Drop = SUM(Is120Drop), 
	Num150Drop = SUM(Is150Drop),
	Num180Drop = SUM(Is180Drop)
FROM
	PYFlagged
GROUP BY
	StartDate, StartPeriod, StartYear, StartNumber, SyCampusID, StartYear, StartNumber

-- Get Delta drop totals
;WITH DeltaDrops AS (
	SELECT
		StartDate,
		StartPeriod,
		StartYear,
		StartNumber,
		TotalNetStart = SUM(NumNetStart),
		TotalReEntry = SUM(NumNetReEntry),
		TotalDrop = SUM(NumDrop),
		TotalDropWithin180 = SUM(NumWithin180Drop),
		Total30Drop = SUM(Num30Drop),
		Total60Drop = SUM(Num60Drop),
		Total90Drop = SUM(Num90Drop),
		Total120Drop = SUM(Num120Drop),
		Total150Drop = SUM(Num150Drop),
		Total180Drop = SUM(Num180Drop)
	FROM
		#Past4TermStartsRollup
	GROUP BY
		StartDate,
		StartPeriod,
		StartYear,
		StartNumber
)
,DeltaDropsPY AS (
	SELECT
		StartDate,
		StartPeriod,
		StartYear,
		StartNumber,
		TotalNetStart = SUM(NumNetStart),
		TotalReEntry = SUM(NumNetReEntry),
		TotalDrop = SUM(NumDrop),
		TotalDropWithin180 = SUM(NumWithin180Drop),
		Total30Drop = SUM(Num30Drop),
		Total60Drop = SUM(Num60Drop),
		Total90Drop = SUM(Num90Drop),
		Total120Drop = SUM(Num120Drop),
		Total150Drop = SUM(Num150Drop),
		Total180Drop = SUM(Num180Drop)
	FROM
		#Past4TermStartsPYRollup
	GROUP BY
		StartDate,
		StartPeriod,
		StartYear,
		StartNumber
)	
---- ======================================================================================
---- Curr Starts
---- ======================================================================================
--CurrStarts AS (
--	SELECT
--		ts.StartDate,
--		ts.StartPeriod, 
--		ts.StartYear,
--		ts.StartNumber,
--		ts.SyCampusID,
--		TotalIncoming = COUNT(ts.AdEnrollID),
--		TotalDrop = SUM(ts.IsDrop) 
--	FROM 
--		#Past4TermStarts ts
--		--INNER JOIN 
--	GROUP BY
--		ts.StartDate,
--		ts.StartPeriod, 
--		ts.StartYear,
--		ts.StartNumber,
--		ts.SyCampusID
--	--ORDER BY
--	--	ts.StartDate DESC,
--	--	ts.SyCampusID
--)

SELECT 
	sr.StartDate,
	sr.StartPeriod,
	sr.SyCampusID,
	Location = c.Descrip,
	--sr.TotalIncoming,
	--sr.TotalDrop,
	--CurrDropPct = CONVERT(NUMERIC(8,2), CONVERT(NUMERIC, sr.TotalDrop) / CONVERT(NUMERIC, cs.TotalIncoming) * 100),
	
	--DeltaTotalIncoming = SUM(cs.TotalIncoming) OVER (PARTITION BY cs.StartDate),
	--DeltaTotalDrop = SUM(cs.TotalDrop) OVER (PARTITION BY cs.StartDate),
	--DeltaDropPct = CONVERT(NUMERIC(8,2), (CONVERT(NUMERIC, SUM(cs.TotalDrop) OVER (PARTITION BY cs.StartDate))) / (CONVERT(NUMERIC, SUM(cs.TotalIncoming) OVER (PARTITION BY cs.StartDate))) * 100),
	
	Incoming = pr.NumNetStart + pr.NumNetReEntry,
	DropWithin180 = pr.NumWithin180Drop,
	Num60Drop = pr.Num60Drop, 
	Num90Drop = pr.Num90Drop, 
	Num120Drop = pr.Num120Drop,
	Num150Drop = pr.Num150Drop,
	Num180Drop = pr.Num180Drop,
	
	DeltaTotalIncoming = dd.TotalNetStart + dd.TotalReEntry,
	DeltaTotalDrop30 = dd.Total30Drop,
	DeltaTotalDrop60 = dd.Total60Drop,
	DeltaTotalDrop90 = dd.Total90Drop,
	DeltaTotalDrop120 = dd.Total120Drop,
	DeltaTotalDrop150 = dd.Total150Drop,
	DeltaTotalDrop180 = dd.Total180Drop,
	----------------------------------------------------------------------
	PriorYrIncoming = prpy.NumNetStart + pr.NumNetReEntry,
	
	--PriorYrDrop30 = prpy.Num30Drop,		-- used for CDG/Gryphon requests not ready to have in reg pop pull (but will integrate in eventually)
	--PriorYrDrop60 = prpy.Num60Drop,
	--PriorYrDrop90 = prpy.Num90Drop,
	--PriorYrDrop120 = prpy.Num120Drop,
	--PriorYrDrop150 = prpy.Num150Drop,
	--PriorYrDrop180 = prpy.Num180Drop,
	PriorYrDropWithin180 = prpy.NumWithin180Drop,
	
	DeltaTotalIncomingPY = ddpy.TotalNetStart + ddpy.TotalReEntry,
	DeltaTotalDrop30PY = ddpy.Total30Drop,
	DeltaTotalDrop60PY = ddpy.Total60Drop,
	DeltaTotalDrop90PY = ddpy.Total90Drop,
	DeltaTotalDrop120PY = ddpy.Total120Drop,
	DeltaTotalDrop150PY = ddpy.Total150Drop,
	DeltaTotalDrop180PY = ddpy.Total180Drop
FROM 
	--CurrStarts cs
	#Past4TermStartsRollup sr
	INNER JOIN Campusvue.dbo.SyCampus c WITH (NOLOCK) ON c.SyCampusID = sr.SyCampusID
	LEFT OUTER JOIN #Past4TermStartsRollup pr ON pr.SyCampusID = sr.SyCampusID AND pr.StartYear = sr.StartYear AND pr.StartNumber = sr.StartNumber
	LEFT OUTER JOIN #Past4TermStartsPYRollup prpy ON prpy.SyCampusID = sr.SyCampusID AND prpy.StartYear = sr.StartYear - 1 AND prpy.StartNumber = sr.StartNumber
	LEFT OUTER JOIN DeltaDrops dd ON dd.StartYear = sr.StartYear AND dd.StartNumber = sr.StartNumber
	LEFT OUTER JOIN DeltaDropsPY ddpy ON ddpy.StartYear = sr.StartYear - 1 AND ddpy.StartNumber = sr.StartNumber
ORDER BY
	sr.StartDate,
	sr.SyCampusID

DROP TABLE #Starts
DROP TABLE #StartsPY
DROP TABLE #Past4TermStarts
DROP TABLE #Past4TermStartsPY




-- ========================================================================================================================
--	Prior logic where time frames based on end of prov period (rather than start date)
-- ========================================================================================================================
--;WITH PYFlagged AS (
--	SELECT 
--		StartDate,
--		StartPeriod,
--		StartYear,
--		StartNumber,
--		SyCampusID,
--		SyStudentID,
--		AdEnrollID,
--		IsNetStart,
--		IsNetReEntry,
--		IsDrop,
--		DropDate,
--		IsWithin180Drop = CASE WHEN (DropDate BETWEEN DATEADD(dd,29,StartDate) AND DATEADD(dd,208,StartDate)) THEN 1 ELSE 0 END,
		
--		--EndProvDate = DATEADD(dd,28,StartDate),
--		IsProvDrop = CASE WHEN (DropDate BETWEEN StartDate AND DATEADD(dd,28,StartDate)) THEN 1 ELSE 0 END,
		
--		--Start30Date = DATEADD(dd,29,StartDate),
--		--End30Date = DATEADD(dd,58,StartDate),
--		Is30Drop = CASE WHEN (DropDate BETWEEN DATEADD(dd,29,StartDate) AND DATEADD(dd,58,StartDate)) THEN 1 ELSE 0 END,
		
--		--Start60Date = DATEADD(dd,59,StartDate),
--		--End60Date = DATEADD(dd,88,StartDate),
--		Is60Drop = CASE WHEN (DropDate BETWEEN DATEADD(dd,59,StartDate) AND DATEADD(dd,88,StartDate)) THEN 1 ELSE 0 END,
		
--		--Start90Date = DATEADD(dd,89,StartDate),
--		--End90Date = DATEADD(dd,118,StartDate),
--		Is90Drop = CASE WHEN (DropDate BETWEEN DATEADD(dd,89,StartDate) AND DATEADD(dd,118,StartDate)) THEN 1 ELSE 0 END,

--		--Start120Date = DATEADD(dd,119,StartDate),
--		--End120Date = DATEADD(dd,148,StartDate),
--		Is120Drop = CASE WHEN (DropDate BETWEEN DATEADD(dd,119,StartDate) AND DATEADD(dd,148,StartDate)) THEN 1 ELSE 0 END,
		
--		--Start150Date = DATEADD(dd,149,StartDate),
--		--End150Date = DATEADD(dd,178,StartDate),
--		Is150Drop = CASE WHEN (DropDate BETWEEN DATEADD(dd,149,StartDate) AND DATEADD(dd,178,StartDate)) THEN 1 ELSE 0 END,
		
--		--Start180Date = DATEADD(dd,179,StartDate),
--		--End180Date = DATEADD(dd,208,StartDate),
--		Is180Drop = CASE WHEN (DropDate BETWEEN DATEADD(dd,179,StartDate) AND DATEADD(dd,208,StartDate)) THEN 1 ELSE 0 END
		
--	FROM 
--		#Past4TermStartsPY
--)