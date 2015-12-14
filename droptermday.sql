SELECT 
 sc.AdEnrollID,
 sc.EffectiveDate,
 e.LDA,
 sc.DateAdded,
 c.descrip AS 'Campus',
 e.ExpStartDate,
 e.reentrydate
 --#xyz

FROM Campusvue.dbo.SyStatChange sc WITH (NOLOCK) 
INNER JOIN Campusvue.dbo.AdEnroll e WITH (NOLOCK) ON e.AdEnrollID = sc.AdEnrollID
INNER JOIN Campusvue.dbo.Sycampus c WITH (NOLOCK) ON c.SycampusID = e.SycampusID
WHERE sc.NewSySchoolStatusID = 20 AND sc.PrevSySchoolStatusID != 20 
	--AND ((sc.EffectiveDate BETWEEN '11/1/2014' AND '11/31/2014') OR (sc.DateAdded BETWEEN '11/1/2014' AND '11/31/2014'))
	--AND e.ExpStartDate BETWEEN '7/01/2014' AND '11/30/2014' AND e.LDA BETWEEN '7/01/2014' AND '11/30/14'
 AND sc.DateAdded >= '11/15/2014' AND sc.DateAdded <= '11/23/2014' 
GROUP BY 
	sc.AdEnrollID,
    sc.DateAdded,
    sc.EffectiveDate,
    e.LDA,
	c.descrip,
	e.ExpStartDate,
	e.reentrydate
		

	ORDER BY e.ExpStartDate 


SELECT *
  --[AdEnrollID]
FROM Systatchange
WHERE 
	[NewSySchoolStatusID] = 20 
	AND PrevSySchoolStatusID = 20
	--AND Type = 'S' 
	AND [EffectiveDate] >= '12/21/2014' AND [EffectiveDate] < '1/31/2015' --AND DateAdded > '09/1/2014'
GROUP BY [AdEnrollID]


SELECT 
  [AdEnrollID]
FROM Systatchange
WHERE [NewSySchoolStatusID] = 20 AND DateAdded >= '12/23/2013' AND DateAdded <= '1/21/2014' AND PrevSySchoolStatusID != 20 
GROUP BY [AdEnrollID]


