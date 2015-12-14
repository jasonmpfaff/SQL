WITH SubmittedProvs AS (
      SELECT
            SyCampusID,
            NumProvs = COUNT(*)
      FROM
            DeltaDataMart.dbo.ProvAtRisk 
      GROUP BY
            SyCampusID
),
CampusCounts AS (
      SELECT
            e.SyCampusID,
            Location = c.Descrip,
            NumProvCancels = COUNT(*),
            NumCorrect = SUM(CASE WHEN (par.SyStudentID IS NOT NULL) THEN 1 ELSE 0 END)
      FROM
            CampusVue.dbo.AdEnroll e WITH (NOLOCK)
            INNER JOIN DeltaDataMart.dbo.GrossEnroll_JulyUpd ge ON ge.AdEnrollID = e.AdEnrollID
            LEFT OUTER JOIN DeltaDataMart.dbo.ProvAtRisk par ON par.SyStudentID = e.SyStudentID
            INNER JOIN CampusVue.dbo.SyCampus c WITH (NOLOCK) ON c.SyCampusID = e.SyCampusID
      WHERE
            e.SySchoolStatusID = 373            -- NEVER ATTEND - Provisional Cancel
            AND e.ExpStartDate = '7/16/2014'
      GROUP BY
            e.SyCampusID,
            c.Descrip
)

SELECT
      cc.SyCampusID,
      cc.Location,
      cc.NumProvCancels,
      NumSubmitted = sp.NumProvs,
      cc.NumCorrect,
      PctOrProvCancelsDetected = CONVERT(NUMERIC(8,1), (CONVERT(NUMERIC, cc.NumCorrect) / CONVERT(NUMERIC, cc.NumProvCancels) * 100)),
      [NumGrossStart],
      [NumProvCancel],
	  Provisionalcancelrate = CONVERT(NUMERIC(8,1), (CONVERT(NUMERIC, NumProvCancel) / CONVERT(NUMERIC, NumGrossStart) * 100))
FROM
      CampusCounts cc 
      LEFT OUTER JOIN SubmittedProvs sp ON sp.SyCampusID = cc.SyCampusID
      LEFT OUTER JOIN [CVCustomReporting].[dbo].[AdmissionsStart_Summary] q ON q.SyCampusID = cc.SyCampusID AND MostRecent = 1 AND StartDate = '7/16/2014'


ORDER BY
      Provisionalcancelrate DESC

