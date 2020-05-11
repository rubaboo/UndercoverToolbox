
--local interrogation proc
--add update to execution logs

ALTER PROC [Catalogue].[LocalInterrogation]
AS

BEGIN

SET NOCOUNT ON

DECLARE @GetDefinition NVARCHAR(MAX)
DECLARE @UpdateDefinition NVARCHAR(MAX)
DECLARE @StageTableName NVARCHAR(128)
DECLARE @cmd NVARCHAR(MAX)

--Update execution audit
INSERT INTO Catalogue.ExecutionLog(ExecutionDate) VALUES(GETDATE())

DECLARE Modules CURSOR STATIC FORWARD_ONLY
FOR
	SELECT GetDefinition, UpdateDefinition, StageTableName
	FROM Catalogue.ConfigModules
	JOIN Catalogue.ConfigModulesDefinitions 
		ON ConfigModules.ID = ConfigModulesDefinitions.ModuleID
	LEFT OUTER JOIN Catalogue.ConfigModulesInstances
		ON Catalogue.ConfigModules.ModuleName = ConfigModulesInstances.ModuleName 
		AND ConfigModulesInstances.ServerName = @@SERVERNAME
	WHERE ISNULL(ConfigModulesInstances.Active, ConfigModules.Active) = 1
	--AND ModuleName = 'Databases'

OPEN Modules

FETCH NEXT FROM Modules INTO @GetDefinition, @UpdateDefinition, @StageTableName

WHILE @@FETCH_STATUS = 0
BEGIN
	--truncate stage tables
	EXEC ('TRUNCATE TABLE Catalogue.' + @StageTableName )

	--insert into stage tables
	SET @cmd = N'INSERT INTO Catalogue.' + @StageTableName + ' EXEC (@GetDefinition)'

	EXEC sp_executesql @cmd, N'@GetDefinition VARCHAR(MAX)', @GetDefinition = @GetDefinition
	
	--execute update code
	EXEC sp_executesql @UpdateDefinition

	FETCH NEXT FROM Modules INTO @GetDefinition, @UpdateDefinition, @StageTableName

END

CLOSE Modules
DEALLOCATE Modules

--Mark execution complete
UPDATE Catalogue.ExecutionLog SET CompletedSuccessfully = 1 FROM Catalogue.ExecutionLog WHERE ID = (SELECT MAX(ID) FROM Catalogue.ExecutionLog)

END
GO

----------------------------------------------------------------------------
--Schema Changes
----------------------------------------------------------------------------

ALTER TABLE Catalogue.Tables 
ADD Rows BIGINT NULL,
	TotalSizeMB BIGINT NULL,
	UsedSizeMB BIGINT NULL
GO

ALTER TABLE Catalogue.Tables_Stage
ADD Rows BIGINT NULL,
	TotalSizeMB BIGINT NULL,
	UsedSizeMB BIGINT NULL
GO

