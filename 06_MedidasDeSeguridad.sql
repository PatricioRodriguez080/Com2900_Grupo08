/*
===============================================================================
Materia:          Bases de Datos Aplicadas
Comisión:         01-2900
Grupo:            G08
Fecha de Entrega: 04/11/2025
Integrantes:
    - Bentancur Suarez, Ismael (45823439)
    - Rodriguez Arrien, Juan Manuel (44259478)
    - Rodriguez, Patricio (45683229)
    - Ruiz, Leonel Emiliano (45537914)
Enunciado:        "06 - Medidas de Seguridad"
===============================================================================
*/

USE Com2900G08;
GO

----------------------------------------------------
-- A. CREACIÓN DE ROLES DE BASE DE DATOS
----------------------------------------------------
-- Se utilizan corchetes [] debido a que algunos nombres contienen espacios.
CREATE ROLE [Administrativo general];
CREATE ROLE [Administrativo Bancario];
CREATE ROLE [Administrativo operativo];
CREATE ROLE [Sistemas];
GO

-- 1. Rol: Administrativo general (Actualización UF y Reportes) --
GRANT UPDATE ON consorcio.unidad_funcional TO [Administrativo general];
GRANT SELECT ON consorcio.expensa TO [Administrativo general];
GRANT SELECT ON consorcio.detalle_expensa TO [Administrativo general];
GO

-- 2. Rol: Administrativo Bancario (Importación Bancaria y Reportes) --
GRANT INSERT ON consorcio.pago TO [Administrativo Bancario]; -- Importación de información bancaria
GRANT SELECT ON consorcio.expensa TO [Administrativo Bancario];
GRANT SELECT ON consorcio.detalle_expensa TO [Administrativo Bancario];
GO

-- 3. Rol: Administrativo operativo (Actualización UF y Reportes) --
GRANT UPDATE ON consorcio.unidad_funcional TO [Administrativo operativo];
GRANT SELECT ON consorcio.expensa TO [Administrativo operativo];
GRANT SELECT ON consorcio.detalle_expensa TO [Administrativo operativo];
GO

-- Rol: Sistemas (Solo Generación de reportes) --
GRANT SELECT ON consorcio.expensa TO [Sistemas];
GRANT SELECT ON consorcio.detalle_expensa TO [Sistemas];
GO

USE master;
GO

--- Creación usuarios Administrativo General ---
-- LUCAS
CREATE LOGIN login_lucas WITH PASSWORD = '4ñ#kZp1@G7X!', CHECK_POLICY = ON;
CREATE USER user_lucas FOR LOGIN login_lucas;
ALTER ROLE [Administrativo general] ADD MEMBER user_lucas;
GO

-- JUAN
CREATE LOGIN login_juan WITH PASSWORD = '9$ñHw2pY!tJ7', CHECK_POLICY = ON;
CREATE USER user_juan FOR LOGIN login_juan;
ALTER ROLE [Administrativo general] ADD MEMBER user_juan;
GO

-- PEDRO
CREATE LOGIN login_pedro WITH PASSWORD = 'B!xñM8@cQ02$', CHECK_POLICY = ON;
CREATE USER user_pedro FOR LOGIN login_pedro;
ALTER ROLE [Administrativo general] ADD MEMBER user_pedro;
GO

--- Creación usuarios Administrativo Bancario ---
-- AXEL
CREATE LOGIN login_axel WITH PASSWORD = 'S8q#ñLz!7E3W', CHECK_POLICY = ON;
CREATE USER user_axel FOR LOGIN login_axel;
ALTER ROLE [Administrativo Bancario] ADD MEMBER user_axel;
GO

-- MARIA
CREATE LOGIN login_maria WITH PASSWORD = 'A7ñ$Rk@49Qx!', CHECK_POLICY = ON;
CREATE USER user_maria FOR LOGIN login_maria;
ALTER ROLE [Administrativo Bancario] ADD MEMBER user_maria;
GO

-- MARTINA
CREATE LOGIN login_martina WITH PASSWORD = '5M!ñPz@1Jk4D', CHECK_POLICY = ON;
CREATE USER user_martina FOR LOGIN login_martina;
ALTER ROLE [Administrativo Bancario] ADD MEMBER user_martina;
GO

--- Creación usuarios Administrativo Operativo ---
-- CAMILA
CREATE LOGIN login_camila WITH PASSWORD = 'ñ2X!g9$T@bL4', CHECK_POLICY = ON;
CREATE USER user_camila FOR LOGIN login_camila;
ALTER ROLE [Administrativo operativo] ADD MEMBER user_camila;
GO

-- PILAR
CREATE LOGIN login_pilar WITH PASSWORD = 'Qñ7@v3!T#cZ1', CHECK_POLICY = ON;
CREATE USER user_pilar FOR LOGIN login_pilar;
ALTER ROLE [Administrativo operativo] ADD MEMBER user_pilar;
GO

-- SOFIA
CREATE LOGIN login_sofia WITH PASSWORD = '1P!ñY5@G8jH$s', CHECK_POLICY = ON;
CREATE USER user_sofia FOR LOGIN login_sofia;
ALTER ROLE [Administrativo operativo] ADD MEMBER user_sofia;
GO

--- Creación usuarios Sistemas ---
-- ALAN
CREATE LOGIN login_alan_sys WITH PASSWORD = 'Zñ3@Hk!8Tq9$', CHECK_POLICY = ON;
CREATE USER user_alan_sys FOR LOGIN login_alan_sys;
ALTER ROLE [Sistemas] ADD MEMBER user_alan_sys;
GO

-- BRUNO
CREATE LOGIN login_bruno_sys WITH PASSWORD = 'ñG7$Qw!5Xp2#', CHECK_POLICY = ON;
CREATE USER user_bruno_sys FOR LOGIN login_bruno_sys;
ALTER ROLE [Sistemas] ADD MEMBER user_bruno_sys;
GO