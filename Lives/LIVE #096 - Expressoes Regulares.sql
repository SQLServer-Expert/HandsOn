/******************************************************************
 Autor: Landry Duailibe
 Data: 25/11/2025

 LIVE #096 - O Que Há de Novo no SQL Server 2025
 - Expressões Regulares 
*******************************************************************/
use AdventureWorks
go

/******************************************
 Função: REGEXP_LIKE
 REGEXP_LIKE (
      string_expression,
      pattern_expression [, flags ] )

 Flags:
'i' ignora maiúsculas/minúsculas (case-insensitive)
'c' força case-sensitive
'm' multilinha: ^ e $ valem por linha
's' dotall: . passa a casar também \n

 https://learn.microsoft.com/en-us/sql/t-sql/functions/regexp-like-transact-sql?view=sql-server-ver17
*******************************************/
-- Lista endereços com formato de e-mail “válido”
SELECT a.BusinessEntityID, a.EmailAddress
FROM Person.EmailAddress a
WHERE REGEXP_LIKE(a.EmailAddress,
'^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$',
'i') -- case-insensitive

/** Explicação ********************************************* 

^[A-Za-z0-9._%+-]
  - Aceita todas as letras maiúsculas "A-Z" e minúsculas "a-z".
  - Aceita qualquer número "0-9"
  - Aceita ".", "%", "+"
  - Como o caractere "-" tem funcionalidade indicando intervalo, para indicar
    o caractere literal "-" tem que colocar o "\" na frente, ficando "\-"

+@
  - Verifica a existência do literal "@"

[A-Za-z0-9.\-]
  - Aceita letras minúsculas e maiúsculas, ponto e "-"

+\.
  - Verifica a existência do literal "."

[A-Za-z]{2,}
  - Somente letras maiúsculas e minúsculas, mas tem que ser no mínimo duas letras.
  - Exemplo joao@contoso.c daria erro porque só tem uma letra depois do ponto

$
  - Não pode ter mais nada depois.
  - Exemplo maria@contoso.com.br123 daria erro devido ao 123 no final

RE2 Regular Expression Syntax:
https://cran.r-project.org/web/packages/re2/vignettes/re2_syntax.html#:%7E:text=The%20simplest%20regular%20expression%20is,matches%20a%20literal%20plus%20character
**********************************************/


/******************************************
 Função: REGEXP_SUBSTR

 https://learn.microsoft.com/en-us/sql/t-sql/functions/regexp-substr-transact-sql?view=sql-server-ver17
*******************************************/
-- Extrair o domínio do e-mail
SELECT a.EmailAddress,
REGEXP_SUBSTR(a.EmailAddress, '@(.+)$', 1, 1, 'c', 1) as Dominio
FROM Person.EmailAddress a


/******************************************
 Função: REGEXP_REPLACE

 https://learn.microsoft.com/en-us/sql/t-sql/functions/regexp-replace-transact-sql?view=sql-server-ver17
*******************************************/
-- Normalizar telefones (remover tudo que não é dígito)
SELECT p.BusinessEntityID, p.PhoneNumber as TelFormatado,
REGEXP_REPLACE(p.PhoneNumber, '[^0-9]', '') AS TelNumeros
FROM Person.PersonPhone p


/******************************************
 Função: REGEXP_COUNT

 https://learn.microsoft.com/en-us/sql/t-sql/functions/regexp-count-transact-sql?view=sql-server-ver17
*******************************************/
-- Quantas letras maiúsculas em cada ProductNumber
SELECT p.ProductID, p.ProductNumber,
REGEXP_COUNT(p.ProductNumber, '[A-Z]') as QtdMaiusculas
FROM Production.Product p
WHERE p.ProductNumber IS NOT NULL

-- Quantos dígitos na chave do pedido (SalesOrderNumber)
SELECT h.SalesOrderID, h.SalesOrderNumber,
REGEXP_COUNT(h.SalesOrderNumber, '\d') as QtdDigitos
FROM Sales.SalesOrderHeader h


/******************************************
 Função: REGEXP_SPLIT_TO_TABLE

 https://learn.microsoft.com/en-us/sql/t-sql/functions/regexp-split-to-table-transact-sql?view=sql-server-ver17
*******************************************/
-- Exemplo: dividir telefones em partes usando o hífen como delimitador
SELECT p.BusinessEntityID, p.PhoneNumber, s.[value] as PhonePart
FROM Person.PersonPhone p
CROSS APPLY REGEXP_SPLIT_TO_TABLE(p.PhoneNumber, '-') as s



