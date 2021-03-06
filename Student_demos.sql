/****** Script for SelectTopNRows command from SSMS  ******/
;WITH tempEd AS (
SELECT 
	   [Location]
      ,[EnrollStatusID]
      ,[EnrollStatus]
      ,[SyStudentID]
      ,[ISIR_FatherHighGradeID]
      ,[ISIR_FatherHighGrade]
      ,[ISIR_MotherHighGradeID]
      ,[ISIR_MotherHighGrade]
	  ,Either4 = CASE WHEN ((ISIR_FatherHighGradeID = 4) OR (ISIR_MotherHighGradeID = 4)) THEN 1 ELSE 0 END
	  ,Either3 = CASE WHEN ((ISIR_FatherHighGradeID = 3) OR (ISIR_MotherHighGradeID = 3)) THEN 1 ELSE 0 END
	  ,Either2 = CASE WHEN ((ISIR_FatherHighGradeID = 2) OR (ISIR_MotherHighGradeID = 2)) THEN 1 ELSE 0 END
	  ,Either1 = CASE WHEN ((ISIR_FatherHighGradeID = 1) OR (ISIR_MotherHighGradeID = 1)) THEN 1 ELSE 0 END
	 

  FROM 
	[DeltaDataMart].[dbo].[GrossEnroll_JulyUpd]

  WHERE
	EnrollStatusID IN (13,14,371,119)
)

SELECT 
	TotalStudents = COUNT(*),
	TotOther = SUM(Either4),
	TotCollege = SUM(Either3),
	TotHS = SUM(Either2),
	TotMiddle = SUM(Either1)

FROM
	TempEd




	SELECT [ISIR_FatherHighGradeID],[ISIR_MotherHighGradeID]
	,NumStudents = COUNT(*)
	FROM 
	[DeltaDataMart].[dbo].[GrossEnroll_JulyUpd]

  WHERE
	EnrollStatusID IN (13,14,371,119)
	GROUP BY
		[ISIR_FatherHighGradeID],
		[ISIR_MotherHighGradeID]
ORDER BY
	[ISIR_FatherHighGradeID],
	[ISIR_MotherHighGradeID]
