/******************************************************************
 Autor: Landry Duailibe
 Data: 25/11/2025

 LIVE #096 - O Que Há de Novo no SQL Server 2025
 - Diferenças das edições Developer
*******************************************************************/
use master
go

DROP DATABASE IF exists HandsON
go
CREATE DATABASE HandsON
go
ALTER DATABASE HandsON SET RECOVERY simple
go

use HandsON
go
CREATE TABLE dbo.Venda (
Venda_ID int not null identity CONSTRAINT pk_Venda PRIMARY KEY,
Data_Venda datetime not null,
Cliente_ID int not null,
Valor decimal(19,2) null)
go

INSERT dbo.Venda (Data_Venda, Cliente_ID, Valor)
VALUES
('20250110 10:15:00',  1, 150.00),
('20250205 19:30:00',  2, 320.50),
('20250312 09:05:00',  3,  89.90),
('20250325 14:20:00',  1, 560.00),
('20250401 11:45:00',  4, 999.99)
go

SELECT * FROM dbo.Venda
/********************** FIM Prepara HandsON *****************************/

/***********************************
 Informações da Edição
************************************/
SELECT @@VERSION
SELECT  SERVERPROPERTY('ServerName'), SERVERPROPERTY ('edition'), SERVERPROPERTY ('productlevel'), 'Build:' + cast(SERVERPROPERTY('productversion') as varchar(2000))

/************************************
 Criação de Índice Online
*************************************/
CREATE NONCLUSTERED INDEX ix_Venda_Data_Venda
ON dbo.Venda (Data_Venda)
WITH (ONLINE = ON)
/*
Msg 1712, Level 16, State 3, Line 42
Online index operations can only be performed in Enterprise edition of SQL Server or Azure SQL Edge.
*/

/************************************
 Ativar Automatic Tuning
*************************************/
ALTER DATABASE HandsON
SET AUTOMATIC_TUNING ( FORCE_LAST_GOOD_PLAN = ON )
/*
Msg 15707, Level 16, State 1, Line 51
Automatic Tuning is available only in the Enterprise and Developer editions of SQL Server.
Msg 5069, Level 16, State 1, Line 51
ALTER DATABASE statement failed.
*/


/******************************
 Exclui Banco
*******************************/
use master
go
DROP DATABASE IF exists HandsON
go

