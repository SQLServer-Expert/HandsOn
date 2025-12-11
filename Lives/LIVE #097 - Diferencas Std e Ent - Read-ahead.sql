/******************************************************************
 Autor: Landry Duailibe
 Data: 02/12/2025

 LIVE #097 - Diferenças entre Std e Ent
 - Plano de Execução
*******************************************************************/
use HandsOn
go

/****************************
 Limita a memória para 2GB
*****************************/
EXEC sys.sp_configure N'max server memory (MB)', N'2048'
go
RECONFIGURE WITH OVERRIDE
go

/*******************************
 Prepara Hands On
********************************/
DROP TABLE IF exists dbo.Cliente
go
CREATE TABLE dbo.Cliente (
Cliente_ID int NOT NULL identity CONSTRAINT pk_Cliente PRIMARY KEY,
TipoCliente_ID char(2) NOT NULL,
TipoCliente varchar(100) NOT NULL,
Nome varchar(100) not null,
Sufixo char(200) NULL,
rowguid uniqueidentifier ROWGUIDCOL  NOT NULL,
DataAlteracao datetime NOT NULL)
go

set nocount on
go
INSERT dbo.Cliente (TipoCliente_ID,TipoCliente, Nome, Sufixo, rowguid, DataAlteracao)
SELECT a.PersonType as TipoCliente_ID, 
case
when a.PersonType = 'SC' then 'Store Contact'
when a.PersonType = 'IN' then 'Individual (retail) customer'
when a.PersonType = 'SP' then 'Sales person'
when a.PersonType = 'EM' then 'Employee (non-sales)'
when a.PersonType = 'VC' then 'Vendor contact'
when a.PersonType = 'GC' then 'General contact'
END as TipoCliente,
FirstName + isnull(' ' + MiddleName,'') + isnull(' ' + LastName,'') as Nome, 
Suffix as Sufixo, rowguid, ModifiedDate as DataAlteracao 
FROM AdventureWorks.Person.Person a
go 400

/***********************
 Backup e Restore
************************/
BACKUP DATABASE HandsOn TO DISK = 'E:\_Lives\Backup\HandsOn.bak' WITH format,compression,stats=5

RESTORE DATABASE HandsOn FROM DISK = 'E:\_Lives\Backup\HandsOn.bak' WITH recovery,stats=5,
move 'HandsOn' to 'E:\MSSQL_Data_STD\HandsOn.mdf',
move 'HandsOn_log' to 'F:\MSSQL_Data_STD\HandsOn_log.ldf'

RESTORE DATABASE HandsOn FROM DISK = 'E:\_Lives\Backup\HandsOn.bak' WITH recovery,stats=5,
move 'HandsOn' to 'E:\MSSQL_Data\HandsOn.mdf',
move 'HandsOn_log' to 'F:\MSSQL_Data\HandsOn_log.ldf'

/************************ FIM Prepara Hands On ******************************/


SELECT count(*) FROM dbo.Cliente
-- 7.988.800 linhas

exec sp_spaceused 'dbo.Cliente'
-- 2.329.672 KB KB


set statistics io on
set statistics io off

-- Desabilita Read-ahead
DBCC TRACEON(652)
DBCC TRACEOFF(652)

CHECKPOINT
DBCC DROPCLEANBUFFERS -- limpa o cache de dados que já foram gravados no disco.
DBCC FREEPROCCACHE -- impa o cache de planos de execução
DBCC FREESYSTEMCACHE ('ALL') -- Limpa TODAS as caches internas do SQL Server
DBCC FREESESSIONCACHE -- Limpa o cache de sessões e parâmetros do SQL Server

SELECT COUNT(distinct TipoCliente) FROM dbo.Cliente OPTION (MAXDOP 1)
/*

- SEM Read-ahead e SEM paralelismo
STD (40 seg) -> Table 'Cliente'. Scan count 1, logical reads 284804, physical reads 284804, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
ENT (22 seg) -> Table 'Cliente'. Scan count 1, logical reads 284804, physical reads 119947, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.

- SEM Read-ahead e COM paralelismo
STD (39 seg) -> Table 'Cliente'. Scan count 5, logical reads 285292, physical reads 284927, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
ENT (21 seg) -> Table 'Cliente'. Scan count 5, logical reads 285236, physical reads 93314, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.

Obs: Batch Mode faz reaproveitar páginas lidas na memória no Enterprise
     - Processa múltiplas linhas de uma vez (vetores)
     - Usa CPU de forma muito mais eficiente

- COM Read-ahead
STD (8 seg) -> Table 'Cliente'. Scan count 1, logical reads 285862, physical reads 4, page server reads 0, read-ahead reads 285857, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
ENT (7 seg) -> Table 'Cliente'. Scan count 1, logical reads 285862, physical reads 3, page server reads 0, read-ahead reads 289782, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.

*/




