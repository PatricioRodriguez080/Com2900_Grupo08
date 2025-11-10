/*
================================================================================
Materia:          Bases de Datos Aplicadas
Comisión:         01-2900
Grupo:            G08
Fecha de Entrega: 04/11/2025
Integrantes:
    - Bentancur Suarez, Ismael (45823439)
    - Rodriguez Arrien, Juan Manuel (44259478)
    - Rodriguez, Patricio (45683229)
    - Ruiz, Leonel Emiliano (45537914)
Enunciado:        "08 - Medidas de Seguridad"
================================================================================
*/

USE Com2900G08;
GO

-- =======================================================
-- ELIMINACIÓN DE USUARIOS DE LA BASE DE DATOS
-- =======================================================

-- Administrativo general
DROP USER IF EXISTS user_lucas;
DROP USER IF EXISTS user_juan;
DROP USER IF EXISTS user_pedro;
GO

-- Administrativo Bancario
DROP USER IF EXISTS user_axel;
DROP USER IF EXISTS user_maria;
DROP USER IF EXISTS user_martina;
GO

-- Administrativo Operativo
DROP USER IF EXISTS user_camila;
DROP USER IF EXISTS user_pilar;
DROP USER IF EXISTS user_sofia;
GO

-- Sistemas
DROP USER IF EXISTS user_alan_sys;
DROP USER IF EXISTS user_bruno_sys;
GO

-- =======================================================
-- ELIMINACIÓN DE ROLES DE LA BASE DE DATOS
-- =======================================================
DROP ROLE IF EXISTS [Administrativo general];
DROP ROLE IF EXISTS [Administrativo Bancario];
DROP ROLE IF EXISTS [Administrativo operativo];
DROP ROLE IF EXISTS [Sistemas];
GO

-- =======================================================
-- ELIMINACIÓN DE LOGINS
-- =======================================================

-- Administrativo general
DROP LOGIN login_lucas;
DROP LOGIN login_juan;
DROP LOGIN login_pedro;
GO

-- Administrativo Bancario
DROP LOGIN login_axel;
DROP LOGIN login_maria;
DROP LOGIN login_martina;
GO

-- Administrativo Operativo
DROP LOGIN login_camila;
DROP LOGIN login_pilar;
DROP LOGIN login_sofia;
GO

-- Sistemas
DROP LOGIN login_alan_sys;
DROP LOGIN login_bruno_sys;
GO

----------------------------------------------------
--  CREACIÓN DE ROLES DE BASE DE DATOS
----------------------------------------------------
CREATE ROLE [Administrativo general];
CREATE ROLE [Administrativo Bancario];
CREATE ROLE [Administrativo operativo];
CREATE ROLE [Sistemas];
GO

-- Actualización de datos de UF para Admin General y Admin Operativo --
GRANT UPDATE ON consorcio.unidad_funcional TO [Administrativo general],[Administrativo operativo];
GRANT SELECT ON consorcio.unidad_funcional TO [Administrativo general],[Administrativo operativo];
GO

-- Importación de información bancaria para Admin Bancario --
GRANT INSERT ON consorcio.pago TO [Administrativo Bancario]; -- Importación de información bancaria
GRANT SELECT ON consorcio.expensa TO [Administrativo Bancario];
GRANT SELECT ON consorcio.detalle_expensa TO [Administrativo Bancario];
GO

-- Generación de reportes para todos los roles --
GRANT EXECUTE ON consorcio.SP_reporte_1 TO [Administrativo general], [Administrativo Bancario], [Administrativo operativo], [Sistemas];
GRANT EXECUTE ON consorcio.SP_reporte_2 TO [Administrativo general], [Administrativo Bancario], [Administrativo operativo], [Sistemas];
GRANT EXECUTE ON consorcio.SP_reporte_3 TO [Administrativo general], [Administrativo Bancario], [Administrativo operativo], [Sistemas];
GRANT EXECUTE ON consorcio.SP_reporte_4 TO [Administrativo general], [Administrativo Bancario], [Administrativo operativo], [Sistemas];
GRANT EXECUTE ON consorcio.SP_reporte_5 TO [Administrativo general], [Administrativo Bancario], [Administrativo operativo], [Sistemas];
GRANT EXECUTE ON consorcio.SP_reporte_6 TO [Administrativo general], [Administrativo Bancario], [Administrativo operativo], [Sistemas];
GO

--- Para la creación de usuarios se contempló la utilización del MUST_CHANGE para forzar al usuario a cambiar su contraseña 
--- luego del primer inicio de sesión, asegurando las buenas practicas de seguridad. Esto no pudo implementarse debido a errores al aplicarlo

--- Creación usuarios Administrativo General ---
-- LUCAS
CREATE LOGIN login_lucas WITH
    PASSWORD = '4ñ#kZp1@G7X!',
    CHECK_POLICY = ON;
CREATE USER user_lucas FOR LOGIN login_lucas WITH DEFAULT_SCHEMA = consorcio;
ALTER ROLE [Administrativo general] ADD MEMBER user_lucas;
GO

-- JUAN
CREATE LOGIN login_juan WITH
    PASSWORD = '9$ñHw2pY!tJ7',
    CHECK_POLICY = ON;
CREATE USER user_juan FOR LOGIN login_juan WITH DEFAULT_SCHEMA = consorcio;
ALTER ROLE [Administrativo general] ADD MEMBER user_juan;
GO

-- PEDRO
CREATE LOGIN login_pedro WITH
    PASSWORD = 'B!xñM8@cQ02$',
    CHECK_POLICY = ON;
CREATE USER user_pedro FOR LOGIN login_pedro WITH DEFAULT_SCHEMA = consorcio;
ALTER ROLE [Administrativo general] ADD MEMBER user_pedro;
GO

--- Creación usuarios Administrativo Bancario ---
-- AXEL
CREATE LOGIN login_axel WITH
    PASSWORD = 'S8q#ñLz!7E3W',
    CHECK_POLICY = ON;
CREATE USER user_axel FOR LOGIN login_axel WITH DEFAULT_SCHEMA = consorcio;
ALTER ROLE [Administrativo Bancario] ADD MEMBER user_axel;
GO

-- MARIA
CREATE LOGIN login_maria WITH
    PASSWORD = 'A7ñ$Rk@49Qx!',
    CHECK_POLICY = ON;
CREATE USER user_maria FOR LOGIN login_maria WITH DEFAULT_SCHEMA = consorcio;
ALTER ROLE [Administrativo Bancario] ADD MEMBER user_maria;
GO

-- MARTINA
CREATE LOGIN login_martina WITH
    PASSWORD = '5M!ñPz@1Jk4D',
    CHECK_POLICY = ON;
CREATE USER user_martina FOR LOGIN login_martina WITH DEFAULT_SCHEMA = consorcio;
ALTER ROLE [Administrativo Bancario] ADD MEMBER user_martina;
GO

--- Creación usuarios Administrativo Operativo ---
-- CAMILA
CREATE LOGIN login_camila WITH
    PASSWORD = 'ñ2X!g9$T@bL4',
    CHECK_POLICY = ON;
CREATE USER user_camila FOR LOGIN login_camila WITH DEFAULT_SCHEMA = consorcio;
ALTER ROLE [Administrativo operativo] ADD MEMBER user_camila;
GO

-- PILAR
CREATE LOGIN login_pilar WITH
    PASSWORD = 'Qñ7@v3!T#cZ1',
    CHECK_POLICY = ON;
CREATE USER user_pilar FOR LOGIN login_pilar WITH DEFAULT_SCHEMA = consorcio;
ALTER ROLE [Administrativo operativo] ADD MEMBER user_pilar;
GO

-- SOFIA
CREATE LOGIN login_sofia WITH
    PASSWORD = '1P!ñY5@G8jH$s',
    CHECK_POLICY = ON;
CREATE USER user_sofia FOR LOGIN login_sofia WITH DEFAULT_SCHEMA = consorcio;
ALTER ROLE [Administrativo operativo] ADD MEMBER user_sofia;
GO

--- Creación usuarios Sistemas ---
-- ALAN
CREATE LOGIN login_alan_sys WITH
    PASSWORD = 'Zñ3@Hk!8Tq9$',
    CHECK_POLICY = ON;
CREATE USER user_alan_sys FOR LOGIN login_alan_sys WITH DEFAULT_SCHEMA = consorcio;
ALTER ROLE [Sistemas] ADD MEMBER user_alan_sys;
GO

-- BRUNO (Tu ejemplo ya estaba correcto)
CREATE LOGIN login_bruno_sys WITH
    PASSWORD = 'ñG7$Qw!5Xp2#',
    CHECK_POLICY = ON;
CREATE USER user_bruno_sys FOR LOGIN login_bruno_sys WITH DEFAULT_SCHEMA = consorcio;
ALTER ROLE [Sistemas] ADD MEMBER user_bruno_sys;
GO

-------- VER USUARIOS CREADOS ------------------
SELECT 
    name AS NombreUsuario,
    type_desc AS Tipo,
    create_date AS FechaCreacion,
    sid AS SID,
    default_schema_name AS EsquemaPorDefecto
FROM 
    sys.database_principals
WHERE 
    type IN ('S', 'U', 'G')
    AND name NOT IN ('public', 'guest', 'INFORMATION_SCHEMA', 'sys', 'dbo');
GO 

-------- VER LOGINS CREADOS ------------------
SELECT
    name AS NombreLogin,
    type_desc AS Tipo,
    create_date AS FechaCreacion,
    sid AS SID
FROM
    sys.server_principals
WHERE
    type = 'S'
    AND name NOT LIKE '##%';
GO

--  Habilitar el modo de autenticación Mixto de SQL Server y Windows
EXEC xp_instance_regwrite N'HKEY_LOCAL_MACHINE', 
    N'Software\Microsoft\MSSQLServer\MSSQLServer', 
    N'LoginMode', REG_DWORD, 2;
GO