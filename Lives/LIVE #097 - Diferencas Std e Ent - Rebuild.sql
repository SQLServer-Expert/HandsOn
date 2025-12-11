/******************************************************************
 Autor: Landry Duailibe
 Data: 02/12/2025

 LIVE #097 - Diferenças entre Std e Ent
 - Rebuild de Indices
 - DBCC CHECKDB
*******************************************************************/
use master
go

/************************************************
 Cria banco Enterprise
*************************************************/
DROP DATABASE IF exists HandsOn
go
CREATE DATABASE HandsOn 
ON  PRIMARY 
(NAME = N'HandsOn', FILENAME = N'E:\MSSQL_Data\HandsOn.mdf' , SIZE = 12GB , MAXSIZE = UNLIMITED, FILEGROWTH = 200MB )
 LOG ON 
(NAME = N'HandsOn_log', FILENAME = N'F:\MSSQL_Data\HandsOn_log.ldf' , SIZE = 400MB , FILEGROWTH = 65536KB )
go
ALTER DATABASE HandsOn SET RECOVERY SIMPLE 
go


/*********************************
 Cria Tabela Grande
**********************************/
use HandsOn
go

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

-- Carrega 7.988.800 linhas (2 min)
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
go 800

-- Cria indice nonclustered (2 min)
CREATE INDEX ix_Cliente_TipoCliente_ID
ON dbo.Cliente (TipoCliente_ID)
INCLUDE (Nome, Sufixo, DataAlteracao)
go
/************************* FIM Prepara Hands On (5 min) ********************************/

/***************************
 Levar banco para Standard
****************************/
BACKUP DATABASE HandsOn TO DISK = 'E:\_Lives\Backup\HandsOn.bak' WITH format,compression,stats=5

RESTORE DATABASE HandsOn FROM DISK = 'E:\_Lives\Backup\HandsOn.bak' WITH recovery,stats=5,
move 'HandsOn' to 'E:\MSSQL_Data_STD\HandsOn.mdf',
move 'HandsOn_log' to 'F:\MSSQL_Data_STD\HandsOn_log.ldf'
/*****************************/

SELECT count(*) FROM dbo.Cliente
-- 15.977.600 linhas

exec sp_spaceused 'dbo.Cliente'
-- 8.385.816 KB

/*************************************************
 1) Rebuild de indices
**************************************************/
SELECT SERVERPROPERTY('Edition') AS Edicao

-- Configurar memória para 2GB
EXEC sys.sp_configure N'show advanced options', 1
GO
RECONFIGURE
GO
EXEC sys.sp_configure N'max server memory (MB)', N'4096'
GO
RECONFIGURE WITH OVERRIDE
GO

-- Abrir outra sessão e mostrar Threads
-- Serial = 1 Paralelo = n
SELECT r.session_id, r.[status], r.command, r.cpu_time, r.total_elapsed_time,
t.task_address, t.scheduler_id, t.exec_context_id
FROM sys.dm_exec_requests r
JOIN sys.dm_os_tasks t ON r.session_id = t.session_id
WHERE r.session_id = 68
ORDER BY t.exec_context_id

-- PARTE 1: Medindo tempo do REBUILD SERIAL (MAXDOP = 1)
--          Este teste deve ser parecido na Standard e na Enterprise
CHECKPOINT
DBCC DROPCLEANBUFFERS -- limpa o cache de dados que já foram gravados no disco.
DBCC FREEPROCCACHE -- Limpa o cache de planos de execução


go
DECLARE @Inicio datetime2, @Fim datetime2
SET @Inicio = SYSDATETIME()

ALTER INDEX pk_Cliente ON dbo.Cliente REBUILD WITH (MAXDOP = 1)

SET @Fim = SYSDATETIME()

SELECT 'pk_Cliente - REBUILD SERIAL (MAXDOP = 1)' AS Operacao,
@Inicio AS Inicio, @Fim AS Fim, DATEDIFF(SECOND, @Inicio, @Fim) AS Segundos
go


-- PARTE 2: Medindo tempo do REBUILD paralelo
--          Enterprise: usa varios workers (paralelismo)
--          Standard: continua serial
CHECKPOINT
DBCC DROPCLEANBUFFERS
DBCC FREEPROCCACHE

go
DECLARE @Inicio datetime2, @Fim datetime2
SET @Inicio = SYSDATETIME()

ALTER INDEX pk_Cliente ON dbo.Cliente REBUILD

SET @Fim = SYSDATETIME()

SELECT 'pk_Cliente - REBUILD' AS Operacao,
@Inicio AS Inicio, @Fim AS Fim, DATEDIFF(SECOND, @Inicio, @Fim) AS Segundos
go

/*
                    Serial      Paralelo
---------------------------------------------
Enterprise (seg)    161          152
---------------------------------------------
Standard (seg)      213
---------------------------------------------
*/

-- Configurar memória para 2GB
EXEC sys.sp_configure N'show advanced options', 1
GO
RECONFIGURE
GO
EXEC sys.sp_configure N'max server memory (MB)', N'2048'
GO
RECONFIGURE WITH OVERRIDE
GO

-- Fragmentação zerada
SELECT i.[name], ips.index_type_desc, index_level,ips.avg_fragmentation_in_percent, ips.page_count
FROM sys.dm_db_index_physical_stats(DB_ID(), OBJECT_ID('dbo.Cliente'), NULL, NULL, 'DETAILED') ips
JOIN sys.indexes i ON ips.object_id = i.object_id 
AND ips.index_id = i.index_id
ORDER BY i.[name],index_level


/*************************************************
 2) DBCC CHECKDB
**************************************************/
-- PARTE 1: Medindo tempo do DBCC CHECKDB SERIAL (Trace Flag 2528)
--          Este teste deve ser parecido na Standard e na Enterprise

-- Desabilita paralelismo do CHECKDB para toda a instancia
DBCC TRACEON(2528, -1) 

go
CHECKPOINT
DBCC DROPCLEANBUFFERS
DBCC FREEPROCCACHE

DECLARE @Inicio datetime2, @Fim datetime2
SET @Inicio = SYSDATETIME()

DBCC CHECKDB ('HandsOn') WITH NO_INFOMSGS

SET @Fim = SYSDATETIME()

SELECT 'DBCC CHECKDB SERIAL' AS Operacao,
@Inicio AS Inicio, @Fim AS Fim, DATEDIFF(SECOND, @Inicio, @Fim) AS Segundos
go

-- Volta ao comportamento padrão
DBCC TRACEOFF(2528, -1)

/*
                    Serial      Paralelo
---------------------------------------------
Enterprise (seg)    22          10
---------------------------------------------
Standard (seg)      24
---------------------------------------------
*/
