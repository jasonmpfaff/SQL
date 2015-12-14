SELECT [INSTNM] AS School_name,[CITY],[STABBR],[CTOTALT] AS Massage_Grads,s.valuelabel AS Sector
FROM [dbo].[IPEDS_CompRate2012Raw] x 
INNER JOIN [dbo].[IPEDS_InstitutionRaw2012] y 
ON y.UNITID = x.UNITID
INNER JOIN [dbo].[IPEDS_InstitutionVarFreq2012] s 
ON s.codevalue=y.SECTOR AND s.varname = 'SECTOR'
WHERE CIPCODE = '"51.0805" AND (y.STABBR = 'NC' OR y.STABBR = 'SC')

