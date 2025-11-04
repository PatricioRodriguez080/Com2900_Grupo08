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
Enunciado:        "03 - Testing de Procedimientos Almacenados ABMs"
===============================================================================
*/

-- ******************************************************************************
-- NOTA IMPORTANTE:
-- Se asume que la base de datos está vacía y los IDs (llaves primarias)
-- se crean de forma AUTONUMÉRICA SECUENCIAL (1, 2, 3, ...). Los IDs de las
-- entidades (UF, Persona, Gasto, etc.) se referencian por su número de inserción
-- secuencial.
-- ******************************************************************************

-------------------
--TESTING CONSORCIO
-------------------

---- INSERTAR CONSORCIO ----

------ 1. CASO EXITOSO (ID: 1) ------
EXEC consorcio.sp_insertarConsorcio
    @idConsorcio = 1,
    @nombre = 'Consorcio A',
    @direccion = 'Calle Falsa 123',
    @cantidadUnidadesFuncionales = 10,
    @metrosCuadradosTotales = 500;

-- Resultado esperado:
-- PRINT: "Consorcio NUEVO insertado con éxito con ID: 1"
-- RETURN = 0

------ 2. ERROR: Consorcio activo con mismo ID ------
EXEC consorcio.sp_insertarConsorcio
    @idConsorcio = 1,
    @nombre = 'Consorcio B',
    @direccion = 'Calle Falsa 123',
    @cantidadUnidadesFuncionales = 15,
    @metrosCuadradosTotales = 600;

-- Resultado esperado:
-- RAISERROR: "Error: Ya existe un consorcio activo con ese ID."
-- RETURN = -1

------ 3. ERROR: Cantidad de UF <= 0 ------
EXEC consorcio.sp_insertarConsorcio
    @idConsorcio = 2,
    @nombre = 'Consorcio C',
    @direccion = 'Calle 1',
    @cantidadUnidadesFuncionales = 0,
    @metrosCuadradosTotales = 400;

-- Resultado esperado:
-- RAISERROR: "Error: La cantidad de unidades funcionales debe ser mayor a 0."
-- RETURN = -3

--------------------------------------------------
---- MODIFICAR CONSORCIO ----
--------------------------------------------------

------ 1. CASO EXITOSO (ID: 1) ------
EXEC consorcio.sp_modificarConsorcio
    @idConsorcio = 1,
    @nombre = 'Consorcio A Modificado',
    @direccion = 'Calle Falsa 456',
    @cantidadUnidadesFuncionales = 12,
    @metrosCuadradosTotales = 550;

-- Resultado esperado:
-- PRINT: "Consorcio con ID: 1 actualizado con exito."
-- RETURN = 0

------ 2. ERROR: Consorcio no existe o está dado de baja ------
EXEC consorcio.sp_modificarConsorcio
    @idConsorcio = 9999,
    @nombre = 'Consorcio Inexistente';

-- Resultado esperado:
-- RAISERROR: "Error: El consorcio no existe o esta dado de baja. No se puede modificar."
-- RETURN = -1

--------------------------------------------------
---- ELIMINAR CONSORCIO ----
--------------------------------------------------

-- *** PREPARACIÓN DE DATOS PARA ELIMINAR CONSORCIO (Errores) ***

-- 1. Insertar Consorcio 3 (para la prueba de UF Activas)
EXEC consorcio.sp_insertarConsorcio
    @idConsorcio = 3,
    @nombre = 'Consorcio B - Con UF Activa',
    @direccion = 'Direccion Test UF',
    @cantidadUnidadesFuncionales = 1,
    @metrosCuadradosTotales = 50;

-- 2. Insertar una Unidad Funcional activa asociada al Consorcio 3
-- UF ID: 1 (Bloquea Consorcio 3)
EXEC consorcio.sp_insertarUnidadFuncional
    @idConsorcio = 3,
    @cuentaOrigen = '9999999999999999999992',
    @numeroUnidadFuncional = 101,
    @piso = '01',
    @departamento = 'A',
    @coeficiente = 10.0,
    @metrosCuadrados = 50,
    @idUFCreada = NULL;


------ 1. CASO EXITOSO (Consorcio 1) ------
EXEC consorcio.sp_eliminarConsorcio
    @idConsorcio = 1;

-- Resultado esperado:
-- PRINT: "Consorcio con ID: 1 dado de baja con exito."
-- RETURN = 0

------ 3. ERROR: Consorcio tiene UF activas asociadas (Consorcio 3) ------
EXEC consorcio.sp_eliminarConsorcio
    @idConsorcio = 3;

-- Resultado esperado:
-- RAISERROR: "Error: No se puede dar de baja el consorcio. Ya que tiene UF activas asociadas."
-- RETURN = -2


--------------------------------------------------
-- *** PREPARACIÓN DE DATOS PARA UF/PERSONA/COCHERA/BAULERA ***
--------------------------------------------------

-- 1. Insertar Consorcio 4 (Base para UF/Persona)
EXEC consorcio.sp_insertarConsorcio
    @idConsorcio = 4,
    @nombre = 'Consorcio D - Para UF (ID 4)',
    @direccion = 'Calle Falsa 123',
    @cantidadUnidadesFuncionales = 10,
    @metrosCuadradosTotales = 500;

-- 2. Insertar Consorcio 5 (Cambio de consorcio - no se usa)
EXEC consorcio.sp_insertarConsorcio
    @idConsorcio = 5,
    @nombre = 'Consorcio E - Destino (ID 5)',
    @direccion = 'Calle C',
    @cantidadUnidadesFuncionales = 5,
    @metrosCuadradosTotales = 100;

-- 3. Insertar Consorcio 7 (Para pruebas de Cochera/Baulera)
EXEC consorcio.sp_insertarConsorcio
    @idConsorcio = 7,
    @nombre = 'Consorcio F - Para Cochera/Baulera (ID 7)',
    @direccion = 'Calle F',
    @cantidadUnidadesFuncionales = 2,
    @metrosCuadradosTotales = 50;


-------------------
--TESTING UNIDAD FUNCIONAL
-------------------

---- INSERTAR UNIDAD FUNCIONAL ----

------ 1. CASO EXITOSO (UF ID: 2 - Consorcio 4) ------
EXEC consorcio.sp_insertarUnidadFuncional
    @idConsorcio = 4,
    @cuentaOrigen = '2000000000000000000001',
    @numeroUnidadFuncional = 101,
    @piso = '01',
    @departamento = 'A',
    @coeficiente = 5.5,
    @metrosCuadrados = 50,
    @idUFCreada = NULL;

-- Resultado esperado:
-- PRINT: "Unidad Funcional insertada con ID: 2"
-- RETURN = 0

------ 2. CASO EXITOSO (UF ID: 3 - Consorcio 4) ------
EXEC consorcio.sp_insertarUnidadFuncional
    @idConsorcio = 4,
    @cuentaOrigen = '2000000000000000000006',
    @numeroUnidadFuncional = 202,
    @piso = '02',
    @departamento = 'A',
    @coeficiente = 5.0,
    @metrosCuadrados = 50,
    @idUFCreada = NULL;

------ 3. ERROR: UF duplicada en el mismo consorcio ------
EXEC consorcio.sp_insertarUnidadFuncional
    @idConsorcio = 4,
    @cuentaOrigen = '2000000000000000000003',
    @numeroUnidadFuncional = 101, -- ya existe en Consorcio 4 (UF 2)
    @piso = '01',
    @departamento = 'C',
    @coeficiente = 5.5,
    @metrosCuadrados = 50;

-- Resultado esperado:
-- RAISERROR: "Error: Ya existe una UF ACTIVA con el numero indicado en este consorcio."
-- RETURN = -2

--------------------------------------------------
---- MODIFICAR UNIDAD FUNCIONAL ----
--------------------------------------------------

------ 1. CASO EXITOSO (Modificar UF ID: 3) ------
EXEC consorcio.sp_modificarUnidadFuncional
    @idUnidadFuncional = 3,
    @numeroUnidadFuncional = 201, -- Cambia de 202
    @coeficiente = 6.0,
    @metrosCuadrados = 55;

-- Resultado esperado:
-- PRINT: "Unidad Funcional modificada exitosamente."
-- RETURN = 0

------ 4. ERROR: Número de UF duplicado en consorcio destino ------
-- Intentar cambiar el número de UF 3 al número 101 (ya usado por UF 2 en Consorcio 4)
EXEC consorcio.sp_modificarUnidadFuncional
    @idUnidadFuncional = 3,
    @numeroUnidadFuncional = 101;

-- Resultado esperado:
-- RAISERROR: "Error: El numero de UF ya esta usado por otra UF activa en el consorcio destino."
-- RETURN = -3

--------------------------------------------------
---- ELIMINAR UNIDAD FUNCIONAL ----
--------------------------------------------------
-- *** PREPARACIÓN DE DATOS PARA ELIMINACIÓN DE UF (Errores) ***

-- 1. Insertar UF 4 (Para error de Propietarios/Inquilinos)
EXEC consorcio.sp_insertarUnidadFuncional
    @idConsorcio = 4, @cuentaOrigen = '2000000000000000000007', @numeroUnidadFuncional = 303,
    @piso = '03', @departamento = 'A', @coeficiente = 5.0, @metrosCuadrados = 50, @idUFCreada = NULL; -- UF ID: 4

-- 2. Insertar UF 5 (Para error de Cocheras/Bauleras)
EXEC consorcio.sp_insertarUnidadFuncional
    @idConsorcio = 4, @cuentaOrigen = '2000000000000000000008', @numeroUnidadFuncional = 404,
    @piso = '04', @departamento = 'A', @coeficiente = 5.0, @metrosCuadrados = 50, @idUFCreada = NULL; -- UF ID: 5

-- 3. Insertar **Cochera 1** asociada a UF 5 (Bloquea eliminación de UF 5 por Cochera)
EXEC consorcio.sp_insertarCochera
    @idUnidadFuncional = 5, @metrosCuadrados = 15, @coeficiente = 1.0, @idCocheraCreada = NULL; -- Cochera ID: 1

-- 4. Insertar **Baulera 1** asociada a UF 5 (Bloquea eliminación de UF 5 por Baulera)
EXEC consorcio.sp_insertarBaulera
    @idUnidadFuncional = 5, @metrosCuadrados = 5, @coeficiente = 0.5, @idBauleraCreada = NULL; -- Baulera ID: 1

-- 5. Insertar Persona 1
EXEC consorcio.sp_insertarPersona
    @nombre = 'Persona UF4', @apellido = 'Propietario', @dni = 88888888,
    @email = 'uf4@mail.com', @telefono = '1111111111', @cuentaOrigen = '2000000000000000000009', @idPersonaCreada = NULL; -- Persona ID: 1

-- 6. Asociar Persona 1 (Propietario) a la UF 4
EXEC consorcio.sp_insertarPersonaUF
    @idPersona = 1, @idUnidadFuncional = 4, @rol = 'propietario';


------ 1. CASO EXITOSO (Eliminar UF ID: 3) ------
EXEC consorcio.sp_eliminarUnidadFuncional
    @idUnidadFuncional = 3;

-- Resultado esperado:
-- PRINT: "Unidad Funcional dada de baja exitosamente."
-- RETURN = 0

------ 3. ERROR: Tiene propietarios o inquilinos (UF 4) ------
EXEC consorcio.sp_eliminarUnidadFuncional
    @idUnidadFuncional = 4;

-- Resultado esperado:
-- RAISERROR: "Error: No se puede dar de baja la UF. Ya que tiene propietarios o inquilinos asignados."
-- RETURN = -2

------ 4. ERROR: Tiene cocheras asociadas (UF 5) ------
EXEC consorcio.sp_eliminarUnidadFuncional
    @idUnidadFuncional = 5;

-- Resultado esperado:
-- RAISERROR: "Error: No se puede dar de baja la UF. Ya que tiene cocheras asociadas."
-- RETURN = -3


--------------------------------------------------
-- *** CONTINUACIÓN DE PREPARACIÓN DE DATOS (PERSONA) ***
--------------------------------------------------

-- 1. Insertar UF 6 (Para asociar personas)
EXEC consorcio.sp_insertarUnidadFuncional
    @idConsorcio = 4, @cuentaOrigen = '2000000000000000000014', @numeroUnidadFuncional = 505,
    @piso = '05', @departamento = 'A', @coeficiente = 5.0, @metrosCuadrados = 50, @idUFCreada = NULL; -- UF ID: 6

-------------------
--TESTING PERSONA
-------------------

---- INSERTAR PERSONA ----

---- 1. CASO EXITOSO (Persona ID: 2) ----
EXEC consorcio.sp_insertarPersona
    @nombre = 'Juan', @apellido = 'Pérez', @dni = 11111111,
    @email = 'juan.perez@mail.com', @telefono = '1234567890',
    @cuentaOrigen = '2000000000000000000001', @idPersonaCreada = NULL;

-- Resultado esperado:
-- PRINT: "Persona insertada con id: 2"
-- RETURN = 0


---- 2. ERROR: DNI ya registrado ----
EXEC consorcio.sp_insertarPersona
    @nombre = 'Ana', @apellido = 'Gómez', @dni = 11111111, -- mismo DNI que Persona 2
    @email = 'ana.gomez@mail.com', @telefono = '0987654321',
    @cuentaOrigen = '2000000000000000000002';

-- Resultado esperado:
-- RAISERROR: "Error: Este dni ya se encuentra registrado."
-- RETURN = -1

--------------------------------------------------
---- MODIFICAR PERSONA ----
--------------------------------------------------

-- *** PREPARACIÓN DE DATOS PARA MODIFICAR PERSONA (Error DNI) ***

-- 1. Insertar una segunda persona para el error de DNI duplicado
-- Persona ID: 3
EXEC consorcio.sp_insertarPersona
    @nombre = 'Persona DNI Duplicado', @apellido = 'Original', @dni = 22222222,
    @email = 'original2@mail.com', @telefono = '1111111112',
    @cuentaOrigen = '2000000000000000000010', @idPersonaCreada = NULL;

---- 1. CASO EXITOSO (Persona ID: 2) ----
EXEC consorcio.sp_modificarPersona
    @idPersona = 2,
    @nombre = 'Juan Ceto',
    @email = 'juan.ceto.01.modificado@mail.com';

-- Resultado esperado:
-- PRINT: "Persona con ID 2 modificada exitosamente."
-- RETURN = 0

---- 3. ERROR: Nuevo DNI ya pertenece a otra persona ----
-- Intentar cambiar el DNI de Persona 2 al DNI de Persona 3 (22222222)
EXEC consorcio.sp_modificarPersona
    @idPersona = 2,
    @dni = 22222222;

-- Resultado esperado:
-- RAISERROR: "Error: El nuevo dni ya le pertenece a otra persona."
-- RETURN = -2

--------------------------------------------------
---- ELIMINAR PERSONA ----
--------------------------------------------------

---- 1. CASO EXITOSO (Persona ID: 2) ----
EXEC consorcio.sp_eliminarPersona
    @idPersona = 2;

-- Resultado esperado:
-- PRINT: "Persona con ID 2 dada de baja exitosamente."
-- RETURN = 0

---- 3. ADVERTENCIA: Persona ya dada de baja ----
EXEC consorcio.sp_eliminarPersona
    @idPersona = 2;

-- Resultado esperado:
-- RAISERROR: "Advertencia: La persona ya se encontraba dada de baja."
-- RETURN = 0


--------------------------------------------------
-- *** PREPARACIÓN DE DATOS PARA PERSONA - UNIDAD FUNCIONAL ***
--------------------------------------------------

-- 1. Insertar Persona 4 (Será el inquilino)
EXEC consorcio.sp_insertarPersona
    @nombre = 'Inquilino Test', @apellido = 'UF', @dni = 33333333,
    @email = 'inquilino@mail.com', @telefono = '1111111113',
    @cuentaOrigen = '2000000000000000000013', @idPersonaCreada = NULL; -- Persona ID: 4

-------------------
--TESTING PERSONA - UNIDAD FUNCIONAL
-------------------

---- INSERTAR PERSONA UNIDAD FUNCIONAL ----

------ 1. CASO EXITOSO (P1 Propietario de UF6) ------
EXEC consorcio.sp_insertarPersonaUF
    @idPersona = 1, -- Persona 1 (Propietario original)
    @idUnidadFuncional = 6, -- UF 6
    @rol = 'propietario';

-- Resultado esperado:
-- PRINT: "Persona y UF relacionadas correctamente"
-- RETURN = 0

------ 5. ERROR: Rol ya ocupado en la UF ------
-- Intentar insertar la Persona 4 como segundo propietario en la UF 6
EXEC consorcio.sp_insertarPersonaUF
    @idPersona = 4,
    @idUnidadFuncional = 6,
    @rol = 'propietario';

-- Resultado esperado:
-- RAISERROR: "Error: Ya existe una persona asignada al rol en la UF. Use el SP de modificar."
-- RETURN = -4

--------------------------------------------------
---- MODIFICAR PERSONA UNIDAD FUNCIONAL ----
--------------------------------------------------

------ 1. CASO EXITOSO (Cambiar Propietario de UF 6: P1 -> P4) ------
EXEC consorcio.sp_modificarPersonaUF
    @idUnidadFuncional = 6,
    @rol = 'propietario',
    @idNuevaPersona = 4;

-- Resultado esperado:
-- PRINT: "Modificacion realizada en la UF con exito."
-- RETURN = 0

------ 5. ERROR: Rol no asignado en la UF ------
-- Asumiendo que la UF 6 no tiene inquilino asignado
EXEC consorcio.sp_modificarPersonaUF
    @idUnidadFuncional = 6,
    @rol = 'inquilino',
    @idNuevaPersona = 1;

-- Resultado esperado:
-- RAISERROR: "Error: No existe un inquilino asignado a la UF. (Use el SP de insertar en su lugar)."
-- RETURN = -4

--------------------------------------------------
---- ELIMINAR PERSONA UNIDAD FUNCIONAL ----
--------------------------------------------------

------ 1. CASO EXITOSO (Eliminar Propietario P4 de UF 6) ------
EXEC consorcio.sp_eliminarPersonaUF
    @idUnidadFuncional = 6,
    @rol = 'propietario';

-- Resultado esperado:
-- PRINT: "Eliminacion realizada con exito"
-- RETURN = 0

------ 3. ERROR: Rol no asignado en la UF ------
-- Suponiendo que la UF 6 no tiene inquilino
EXEC consorcio.sp_eliminarPersonaUF
    @idUnidadFuncional = 6,
    @rol = 'inquilino';

-- Resultado esperado:
-- RAISERROR: "Error: No existe un inquilino asignado a la UF."
-- RETURN = -2


-------------------
--TESTING COCHERA
-------------------

---- INSERTAR COCHERA ----

------ 1. CASO EXITOSO (Cochera ID: 2 - Asignada a UF 6) ------
EXEC consorcio.sp_insertarCochera
    @idUnidadFuncional = 6, -- UF 6
    @metrosCuadrados = 15, @coeficiente = 1.50, @idCocheraCreada = NULL;

-- Resultado esperado:
-- PRINT: "Cochera insertada con exito con ID: 2"
-- RETURN = 0

------ 2. CASO EXITOSO (Cochera ID: 3 - Sin Asignar) ------
EXEC consorcio.sp_insertarCochera
    @idUnidadFuncional = NULL, @metrosCuadrados = 12, @coeficiente = 1.00, @idCocheraCreada = NULL;

-- Resultado esperado:
-- PRINT: "Cochera insertada con exito con ID: 3"
-- RETURN = 0

--------------------------------------------------
---- MODIFICAR COCHERA ----

------ 2. CASO EXITOSO (Asignar a UF - Cochera 2 a UF 4) ------
EXEC consorcio.sp_modificarCochera
    @idCochera = 2, @idUnidadFuncional = 4; -- UF 4

-- Resultado esperado:
-- PRINT: "Cochera con ID: 2 actualizada con exito."
-- RETURN = 0

------ 3. CASO EXITOSO (Desasignar de UF - Cochera 3 a NULL) ------
EXEC consorcio.sp_modificarCochera
    @idCochera = 3, @idUnidadFuncional = NULL;

-- Resultado esperado:
-- PRINT: "Cochera con ID: 3 actualizada con exito."
-- RETURN = 0

--------------------------------------------------
---- ELIMINAR COCHERA ----

------ 1. CASO EXITOSO (Eliminar Cochera 3) ------
EXEC consorcio.sp_eliminarCochera
    @idCochera = 3;

-- Resultado esperado:
-- PRINT: "Cochera con ID: 3 eliminada con exito."
-- RETURN = 0

------ 3. ERROR: Asignada a UF (Cochera 2) ------
EXEC consorcio.sp_eliminarCochera
    @idCochera = 2;

-- Resultado esperado:
-- RAISERROR: "Error: La cochera esta asignada a una UF. Primero debe desasignarla."
-- RETURN = -2


-------------------
--TESTING BAULERA
-------------------

---- INSERTAR BAULERA ----

------ 1. CASO EXITOSO (Baulera ID: 2 - Asignada a UF 6) ------
EXEC consorcio.sp_insertarBaulera
    @idUnidadFuncional = 6, @metrosCuadrados = 8, @coeficiente = 0.80, @idBauleraCreada = NULL; -- UF 6

-- Resultado esperado:
-- PRINT: "Baulera insertada con exito con ID: 2"
-- RETURN = 0

------ 2. CASO EXITOSO (Baulera ID: 3 - Sin Asignar) ------
EXEC consorcio.sp_insertarBaulera
    @idUnidadFuncional = NULL, @metrosCuadrados = 6, @coeficiente = 0.60, @idBauleraCreada = NULL;

-- Resultado esperado:
-- PRINT: "Baulera insertada con exito con ID: 3"
-- RETURN = 0

--------------------------------------------------
---- MODIFICAR BAULERA ----

------ 2. CASO EXITOSO (Asignar a UF - Baulera 3 a UF 6) ------
EXEC consorcio.sp_modificarBaulera
    @idBaulera = 3, @idUnidadFuncional = 6;

-- Resultado esperado:
-- PRINT: "Baulera con ID: 3 actualizada con exito."
-- RETURN = 0

------ 3. CASO EXITOSO (Desasignar de UF - Baulera 3 a NULL) ------
EXEC consorcio.sp_modificarBaulera
    @idBaulera = 3, @idUnidadFuncional = NULL;

-- Resultado esperado:
-- PRINT: "Baulera con ID: 3 actualizada con exito."
-- RETURN = 0

--------------------------------------------------
---- ELIMINAR BAULERA ----

------ 1. CASO EXITOSO (Eliminar Baulera 3) ------
EXEC consorcio.sp_eliminarBaulera
    @idBaulera = 3;

-- Resultado esperado:
-- PRINT: "Baulera con ID: 3 eliminada con exito."
-- RETURN = 0

------ 3. ERROR: Asignada a UF (Baulera 2) ------
EXEC consorcio.sp_eliminarBaulera
    @idBaulera = 2;

-- Resultado esperado:
-- RAISERROR: "Error: La baulera esta asignada a una UF. Primero debe desasignarla."
-- RETURN = -2



-------------------
--TESTING EXPENSA
-------------------

-- *** PREPARACIÓN DE DATOS PARA EXPENSA y GASTOS ***

-- 1. Crear Consorcio 8 (Para Expensa/Gasto)
EXEC consorcio.sp_insertarConsorcio
    @idConsorcio = 8, @nombre = 'Consorcio H - Para Expensa (ID 8)', @direccion = 'Calle H',
    @cantidadUnidadesFuncionales = 2, @metrosCuadradosTotales = 50;

-- 2. Crear Consorcio 9 (Para Gastos)
EXEC consorcio.sp_insertarConsorcio
    @idConsorcio = 9, @nombre = 'Consorcio I - Para Gastos (ID 9)', @direccion = 'Calle I',
    @cantidadUnidadesFuncionales = 3, @metrosCuadradosTotales = 150;

-- ** AÑADIDO: Insertar Unidad Funcional 7 (UF ID: 7) para Consorcio 9 **
EXEC consorcio.sp_insertarUnidadFuncional
    @idConsorcio = 9, @cuentaOrigen = '9000000000000000000001', @numeroUnidadFuncional = 101,
    @piso = '01', @departamento = 'A', @coeficiente = 10.0, @metrosCuadrados = 50; -- UF ID: 7

-- 3. Insertar Expensa 1 (Para CASO EXITOSO/ELIMINAR)
EXEC consorcio.sp_insertarExpensa @idConsorcio = 8, @periodo = 'enero', @anio = 2025; -- EXP ID: 1

-- 4. Insertar Expensa 2 (Para bloqueo por Gasto)
EXEC consorcio.sp_insertarExpensa @idConsorcio = 8, @periodo = 'febrero', @anio = 2025; -- EXP ID: 2
-- Bloquear la Expensa 2 insertando un Gasto Padre (Gasto ID: 1)
EXEC consorcio.sp_insertarGasto @idExpensa = 2, @subTotalOrdinarios = 100.00, @subTotalExtraOrd = 0.00;

-- 5. Crear Expensa 3 (Sin detalle - Para insert Gasto exitoso)
EXEC consorcio.sp_insertarExpensa @idConsorcio = 9, @periodo = 'marzo', @anio = 2026; -- EXP ID: 3

-- 6. Crear Expensa 4 (CON detalle - Para error de bloqueo)
EXEC consorcio.sp_insertarExpensa @idConsorcio = 9, @periodo = 'abril', @anio = 2026; -- EXP ID: 4
-- Gasto ID: 2 (Bloqueado) asociado a Expensa 4
EXEC consorcio.sp_insertarGasto @idExpensa = 4, @subTotalOrdinarios = 100.00, @subTotalExtraOrd = 0.00;

-- 7. Crear Expensa 5 (Para eliminación Gasto exitosa/error)
EXEC consorcio.sp_insertarExpensa @idConsorcio = 9, @periodo = 'mayo', @anio = 2026; -- EXP ID: 5
-- Gasto ID: 3 (Eliminación exitosa) asociado a Expensa 5
EXEC consorcio.sp_insertarGasto @idExpensa = 5, @subTotalOrdinarios = 100.00, @subTotalExtraOrd = 0.00;
-- Gasto ID: 4 (Error eliminación por detalle Gasto Ord) asociado a Expensa 5
EXEC consorcio.sp_insertarGasto @idExpensa = 5, @subTotalOrdinarios = 100.00, @subTotalExtraOrd = 0.00;

-- 8. Insertar Gasto Ordinario 1 (GastoOrd ID: 1) para el Gasto 4 (para forzar error de eliminación Gasto)
EXEC consorcio.sp_insertarGastoOrdinario
    @idGasto = 4, @tipoGasto = 'Limpieza', @subTipoGasto = 'Personal', @nomEmpresa = 'Bloqueo Gasto 4',
    @nroFactura = 4000, @importe = 1.00;

-- 9. Insertar un detalle_expensa ficticio para BLOQUEAR la Expensa 4
-- Detalle Expensa ID: 1
EXEC consorcio.sp_insertarDetalleExpensa
    @idExpensa = 4, @idUnidadFuncional = 7, -- **CORREGIDO: Usando UF 7 (Consorcio 9)**
    @fechaPrimerVenc = '2026-04-10', @saldoAnterior = 0.00,
    @pagoRecibido = 0.00, @deuda = 0.00, @interesPorMora = 0.00, @expensasOrdinarias = 50.00, @expensasExtraordinarias = 0.00,
    @totalAPagar = 50.00, @fechaEmision = '2026-04-01';
--------------------------------------------------

---- INSERTAR EXPENSA ----

---- 4. ERROR: Expensa duplicada (mismo consorcio 8, periodo y año) ----
EXEC consorcio.sp_insertarExpensa
    @idConsorcio = 8, @periodo = 'enero', @anio = 2025; -- Duplicado de EXP 1

-- Resultado esperado:
-- RAISERROR: "Error: Ya existe un cierre de expensa para el Consorcio X en el periodo Y del año Z."
-- RETURN = -3


---- MODIFICAR EXPENSA ----

---- 1. CASO EXITOSO (EXP ID: 1) ----
EXEC consorcio.sp_modificarExpensa
    @idExpensa = 1, @periodo = 'marzo', @anio = 2026;

-- Resultado esperado:
-- PRINT: "Cierre de Expensa ID: 1 actualizado con exito."
-- RETURN = 0


---- 3. ERROR: Expensa con gastos o detalles asociados (EXP ID: 2) ----
EXEC consorcio.sp_modificarExpensa
    @idExpensa = 2, -- Expensa con Gasto padre asociado (Gasto 1)
    @anio = 2025;

-- Resultado esperado:
-- RAISERROR: "Error: El cierre de expensa ID 2 ya tiene gastos o detalles asociados. No se puede modificar."
-- RETURN = -2


---- ELIMINAR EXPENSA ----

---- 1. CASO EXITOSO (EXP ID: 1) ----
EXEC consorcio.sp_eliminarExpensa
    @idExpensa = 1;

-- Resultado esperado:
-- PRINT: "Expensa con ID: 1 eliminada con exito."
-- RETURN = 0


---- 3. ERROR: Expensa con gastos o detalles asociados (EXP ID: 2) ----
EXEC consorcio.sp_eliminarExpensa
    @idExpensa = 2;

-- Resultado esperado:
-- RAISERROR: "Error: La expensa ya tiene gastos o detalles asociados. No se puede eliminar."
-- RETURN = -2

--------------------------------------------------
-- **** RESTO DEL SCRIPT CORREGIDO ****
--------------------------------------------------

-------------------
--TESTING GASTO
-------------------

---- INSERTAR GASTO ----

------ 1. CASO EXITOSO (Gasto ID: 5 asociado a Expensa 3) ------
EXEC consorcio.sp_insertarGasto
    @idExpensa = 3, @subTotalOrdinarios = 1500.50, @subTotalExtraOrd = 500.00;

-- Resultado esperado:
-- PRINT: "Gasto insertado con exito con ID: 5 para el Cierre ID 3."
-- RETURN = 0

------ 3. ERROR: Expensa con detalle generado (cierre bloqueado) ------
EXEC consorcio.sp_insertarGasto
    @idExpensa = 4, -- Expensa CON detalle_expensa (Detalle Expensa 1)
    @subTotalOrdinarios = 200.00, @subTotalExtraOrd = 100.00;

-- Resultado esperado:
-- RAISERROR: "Error: No se pueden cargar mas gastos a la expensa de ID 4. Ya se genero al menos un detalle_expensa."
-- RETURN = -2


---- MODIFICAR GASTO ----

------ 1. CASO EXITOSO: Modificar ambos subtotales (Gasto ID: 5) ------
EXEC consorcio.sp_modificarGasto
    @idGasto = 5,
    @subTotalOrdinarios = 2000.00, @subTotalExtraOrd = 600.00;

-- Resultado esperado:
-- PRINT: "Gasto con ID: 5 actualizado con exito."
-- RETURN = 0

------ 4. ERROR: Expensa con detalle generado (cierre bloqueado) ------
EXEC consorcio.sp_modificarGasto
    @idGasto = 2, -- Gasto asociado a Expensa ID 4 (CON detalle_expensa 1)
    @subTotalOrdinarios = 50.00;

-- Resultado esperado:
-- RAISERROR: "Error: No se puede modificar el gasto de ID 2. Ya se genero al menos un detalle para la expensa ID 4."
-- RETURN = -2


---- ELIMINAR GASTO ----

------ 1. CASO EXITOSO (Gasto ID: 3) ------
EXEC consorcio.sp_eliminarGasto
    @idGasto = 3;

-- Resultado esperado:
-- PRINT: "Gasto con ID: 3 eliminado con exito."
-- RETURN = 0

------ 3. ERROR: Expensa con detalle generado (cierre bloqueado) ------
EXEC consorcio.sp_eliminarGasto
    @idGasto = 2;

-- Resultado esperado:
-- RAISERROR: "Error: No se puede eliminar el gasto de ID 2. Ya se genero al menos un detalle para la expensa de ID 4."
-- RETURN = -2

------ 4. ERROR: Gasto tiene detalles ordinarios/extraordinarios asociados (Gasto ID: 4) ------
EXEC consorcio.sp_eliminarGasto
    @idGasto = 4; -- Gasto CON Gasto Ordinario 1

-- Resultado esperado:
-- RAISERROR: "Error: No se puede eliminar el gasto de ID 4. Tiene gastos ordinarios/extraordinarios asociados. Elimine esos detalles primero."
-- RETURN = -3



--------------------------------------ACA ROMPE--------------------------------------
-------------------
--TESTING GASTO ORDINARIO
-------------------

-- *** PREPARACIÓN DE DATOS PARA GASTO ORDINARIO ***

-- 1. Gasto Ordinario 2 (GastoOrd ID: 2 - para el test de factura duplicada)
EXEC consorcio.sp_insertarGastoOrdinario
    @idGasto = 5, @tipoGasto = 'Limpieza', @subTipoGasto = 'Insumos', @nomEmpresa = 'Empresa Z',
    @nroFactura = 2000, @importe = 100.00;

-- 2. Gasto Ordinario 3 (GastoOrd ID: 3 - asociado a Gasto 2 Bloqueado)
EXEC consorcio.sp_insertarGastoOrdinario
    @idGasto = 2, -- Gasto 2 Bloqueado (Expensa 4)
    @tipoGasto = 'Administracion', @subTipoGasto = 'Honorarios', @nomEmpresa = 'Bloqueado S.A.',
    @nroFactura = 3000, @importe = 50.00;


---- INSERTAR GASTO ORDINARIO ----

------ 1. CASO EXITOSO (GastoOrd ID: 4) ------
EXEC consorcio.sp_insertarGastoOrdinario
    @idGasto = 5, @tipoGasto = 'Mantenimiento', @subTipoGasto = 'Ascensor', @nomEmpresa = 'Empresa A',
    @nroFactura = 1001, @importe = 850.75;

-- Resultado esperado:
-- PRINT: "Gasto Ordinario insertado con ID: 4"
-- RETURN = 0

------ 3. ERROR: Expensa con detalle generado (cierre bloqueado) ------
EXEC consorcio.sp_insertarGastoOrdinario
    @idGasto = 2, -- Gasto 2 asociado a Expensa ID 4 (CON detalle_expensa 1)
    @tipoGasto = 'Administracion', @subTipoGasto = 'Honorarios', @nomEmpresa = 'Empresa C',
    @nroFactura = 1003, @importe = 50.00;

-- Resultado esperado:
-- RAISERROR: "Error: No se pueden cargar mas gastos a la expensa. Ya se emitierio su detalle."
-- RETURN = -2

------ 5. ERROR: Factura duplicada para la misma empresa ------
EXEC consorcio.sp_insertarGastoOrdinario
    @idGasto = 5, @tipoGasto = 'Generales', @subTipoGasto = 'Varios', @nomEmpresa = 'Empresa A',
    @nroFactura = 1001, -- Mismo número de factura que Gasto Ord 4
    @importe = 50.00;

-- Resultado esperado:
-- RAISERROR: "Error: Ya existe un gasto ordinario con el Nro. de Factura 1001 para la empresa Empresa A."
-- RETURN = -4


---- MODIFICAR GASTO ORDINARIO ----

------ 1. CASO EXITOSO: Modificar múltiples campos (GastoOrd ID: 4) ------
EXEC consorcio.sp_modificarGastoOrdinario
    @idGastoOrd = 4, @tipoGasto = 'SERVICIOS PUBLICOS', @subTipoGasto = 'Luz', @importe = 900.00;

-- Resultado esperado:
-- PRINT: "Gasto Ordinario ID: 4 actualizado con exito."
-- RETURN = 0

------ 4. ERROR: Gasto asociado a expensa con detalle generado (cierre bloqueado) ------
EXEC consorcio.sp_modificarGastoOrdinario
    @idGastoOrd = 3, -- GastoOrd 3 asociado a Gasto 2 (Expensa 4 Bloqueada)
    @importe = 50.00;

-- Resultado esperado:
-- RAISERROR: "Error: No se puede modificar el Gasto Ordinario de ID 3. Ya se emitio un detalle para la expensa."
-- RETURN = -2


---- ELIMINAR GASTO ORDINARIO ----

------ 1. CASO EXITOSO (GastoOrd ID: 2) ------
EXEC consorcio.sp_eliminarGastoOrdinario
    @idGastoOrd = 2;

-- Resultado esperado:
-- PRINT: "Gasto Ordinario con ID: 2 eliminado con exito."
-- RETURN = 0

------ 3. ERROR: Gasto asociado a expensa con detalle generado (cierre bloqueado) ------
EXEC consorcio.sp_eliminarGastoOrdinario
    @idGastoOrd = 3;

-- Resultado esperado:
-- RAISERROR: "Error: No se puede eliminar el Gasto Ordinario de ID 3. Ya se emitio un detalle para la expensa de ID 4."
-- RETURN = -2


-------------------
--TESTING GASTO EXTRA ORDINARIO
-------------------

-- *** PREPARACIÓN DE DATOS PARA GASTO EXTRAORDINARIO ***

-- 1. Gasto Extraordinario 1 (GEO ID: 1 - asociado a Gasto 2 Bloqueado)
EXEC consorcio.sp_insertarGastoExtraOrdinario
    @idGasto = 2, -- Gasto 2 Bloqueado (Expensa 4)
    @tipoGasto = 'Reparacion', @nomEmpresa = 'Bloqueado Extra S.A.', @nroFactura = 7000, @descripcion = 'Bloqueo',
    @nroCuota = 1, @totalCuotas = 1, @importe = 1.00;

-- 2. Gasto Extraordinario 2 (GEO ID: 2 - para el test de factura duplicada)
EXEC consorcio.sp_insertarGastoExtraOrdinario
    @idGasto = 5, @tipoGasto = 'Reparacion', @nomEmpresa = 'Unica SA', @nroFactura = 6000, @descripcion = 'Original para duplicar',
    @nroCuota = 1, @totalCuotas = 1, @importe = 100.00;

---- INSERTAR GASTO EXTRA ORDINARIO ----

------ 1. CASO EXITOSO (GEO ID: 3 - Construcción, 1/3) ------
EXEC consorcio.sp_insertarGastoExtraOrdinario
    @idGasto = 5, @tipoGasto = 'Construccion', @nomEmpresa = 'Constructora X', @nroFactura = 5001, @descripcion = 'Ampliacion de terraza',
    @nroCuota = 1, @totalCuotas = 3, @importe = 15000.00;

-- Resultado esperado:
-- PRINT: "Gasto Extraordinario insertado con ID: 3"
-- RETURN = 0

------ 4. ERROR: Expensa con detalle generado (cierre bloqueado) ------
EXEC consorcio.sp_insertarGastoExtraOrdinario
    @idGasto = 2,
    @tipoGasto = 'Construccion', @nomEmpresa = 'Bloqueado S.A.', @nroFactura = 5004, @descripcion = 'No debe insertarse',
    @nroCuota = 1, @totalCuotas = 1, @importe = 1.00;

-- Resultado esperado:
-- RAISERROR: "Error: No se pueden cargar mas gastos extraordinarios. Ya se emitio un detalle de la expensa."
-- RETURN = -2

------ 8. ERROR: Factura duplicada para la misma empresa ------
EXEC consorcio.sp_insertarGastoExtraOrdinario
    @idGasto = 5, @tipoGasto = 'Construccion', @nomEmpresa = 'Constructora X', -- Misma empresa que GEO 3
    @nroFactura = 5001, -- Mismo número de factura que GEO 3
    @importe = 10.00;

-- Resultado esperado:
-- RAISERROR: "Error: Ya existe un gasto extraordinario con el Nro. de Factura 5001 para la empresa Constructora X."
-- RETURN = -6


---- MODIFICAR GASTO EXTRA ORDINARIO ----

------ 1. CASO EXITOSO: Modificar tipo, descripción e importe (GEO ID: 3) ------
EXEC consorcio.sp_modificarGastoExtraOrdinario
    @idGastoExtraOrd = 3, @tipoGasto = 'REPARACION', @descripcion = 'Arreglo menor de terraza', @importe = 14500.00;

-- Resultado esperado:
-- PRINT: "Gasto Extraordinario ID: 3 actualizado con exito."
-- RETURN = 0

------ 4. ERROR: Gasto asociado a expensa con detalle generado (cierre bloqueado) ------
EXEC consorcio.sp_modificarGastoExtraOrdinario
    @idGastoExtraOrd = 1, -- GEO 1 asociado a Expensa 4 (Bloqueado)
    @importe = 50.00;

-- Resultado esperado:
-- RAISERROR: "Error: No se puede modificar el Gasto Extraordinario de ID 1. Ya se emitio un detalle para la expensa."
-- RETURN = -2


---- ELIMINAR GASTO EXTRA ORDINARIO ----

------ 1. CASO EXITOSO (GEO ID: 2) ------
EXEC consorcio.sp_eliminarGastoExtraOrdinario
    @idGastoExtraOrd = 2;

-- Resultado esperado:
-- PRINT: "Gasto Extraordinario con ID: 2 eliminado con exito."
-- RETURN = 0

------ 3. ERROR: Gasto asociado a expensa con detalle generado (cierre bloqueado) ------
EXEC consorcio.sp_eliminarGastoExtraOrdinario
    @idGastoExtraOrd = 1;

-- Resultado esperado:
-- RAISERROR: "Error: No se puede eliminar el Gasto Extraordinario ID 1. Ya se emitiio un detalle para la expensa de ID 4."
-- RETURN = -2

--------------------------------------------------
-- **** TESTING DETALLE EXPENSA Y PAGO ****
--------------------------------------------------

-- *** PREPARACIÓN DE DATOS PARA DETALLE EXPENSA Y PAGO ***

-- 1. Consorcio 10 (Base)
EXEC consorcio.sp_insertarConsorcio
    @idConsorcio = 10, @nombre = 'Consorcio J - Base Detalle/Pago (ID 10)', @direccion = 'Calle J',
    @cantidadUnidadesFuncionales = 2, @metrosCuadradosTotales = 50;

-- 2. Expensa 6 (EXP ID: 6 - para pruebas de éxito/error de pago/detalle.)
EXEC consorcio.sp_insertarExpensa
    @idConsorcio = 10, @periodo = 'Agosto', @anio = 2025, @fechaEmision = '2025-08-01';

-- 3. Expensa 7 (EXP ID: 7 - para bloqueo por pago.)
EXEC consorcio.sp_insertarExpensa
    @idConsorcio = 10, @periodo = 'Septiembre', @anio = 2025, @fechaEmision = '2025-09-01';

-- 4. Unidad Funcional 8 (UF ID: 8) **AÑADIDO: para Consorcio 10**
EXEC consorcio.sp_insertarUnidadFuncional
    @idConsorcio = 10, @cuentaOrigen = '2000000000000000000008', @numeroUnidadFuncional = 801,
    @piso = '08', @departamento = 'A', @coeficiente = 5.0, @metrosCuadrados = 50; -- UF ID: 8

-- 5. Unidad Funcional 9 (UF ID: 9)
EXEC consorcio.sp_insertarUnidadFuncional
    @idConsorcio = 10, @cuentaOrigen = '2000000000000000000009', @numeroUnidadFuncional = 901,
    @piso = '09', @departamento = 'A', @coeficiente = 5.0, @metrosCuadrados = 50; -- UF ID: 9

-- 6. Detalle Expensa 2 (DE ID: 2 - para pruebas de éxito)
EXEC consorcio.sp_insertarDetalleExpensa
    @idExpensa = 6, @idUnidadFuncional = 9, @fechaPrimerVenc = '2025-08-10', @saldoAnterior = 100.00, @pagoRecibido = 0.00,
    @deuda = 100.00, @interesPorMora = 0.00, @expensasOrdinarias = 500.00, @expensasExtraordinarias = 0.00,
    @totalAPagar = 600.00, @fechaEmision = '2025-08-01';

-- 7. Detalle Expensa 3 (DE ID: 3 - para pruebas de bloqueo)
EXEC consorcio.sp_insertarDetalleExpensa
    @idExpensa = 7, @idUnidadFuncional = 8, -- **CORREGIDO: Usando UF 8 (Consorcio 10)**
    @fechaPrimerVenc = '2025-09-10', @saldoAnterior = 50.00, @pagoRecibido = 0.00,
    @deuda = 50.00, @interesPorMora = 0.00, @expensasOrdinarias = 300.00, @expensasExtraordinarias = 100.00,
    @totalAPagar = 450.00, @fechaEmision = '2025-09-01';

-- 8. PAGO 1 (PAGO ID: 1) para bloquear el Detalle 3
EXEC consorcio.sp_insertarPago
    @idDetalleExpensa = 3, @monto = 450.00, @fecha = '2025-09-05';

-- 9. Asegurar el bloqueo del Detalle Expensa 3
UPDATE consorcio.detalle_expensa SET idPago = 1 WHERE idDetalleExpensa = 3;

---------------------------------------------------
-- **** TESTING DETALLE EXPENSA ****
---------------------------------------------------

---- INSERTAR DETALLE EXPENSA ----

------ 1. CASO EXITOSO (DE ID: 4) ------
EXEC consorcio.sp_insertarDetalleExpensa
    @idExpensa = 6, @idUnidadFuncional = 8, -- **CORREGIDO: Usando UF 8**
    @fechaPrimerVenc = '2025-08-10', @saldoAnterior = 0.00, @pagoRecibido = 0.00, @deuda = 0.00, @interesPorMora = 0.00,
    @expensasOrdinarias = 250.00, @expensasExtraordinarias = 0.00, @totalAPagar = 250.00,
    @fechaEmision = '2025-08-01';

-- Resultado esperado:
-- PRINT: "Detalle de Expensa insertado con ID: 4"
-- RETURN = 0

------ 2. ERROR: Detalle de Expensa duplicado (Expensa 6 + UF 9) ------
EXEC consorcio.sp_insertarDetalleExpensa
    @idExpensa = 6, @idUnidadFuncional = 9, -- Duplicado de DE 2
    @fechaPrimerVenc = '2025-08-10', @saldoAnterior = 0.00, @pagoRecibido = 0.00, @deuda = 0.00, @interesPorMora = 0.00,
    @expensasOrdinarias = 100.00, @expensasExtraordinarias = 0.00, @totalAPagar = 100.00;

-- Resultado esperado:
-- RAISERROR: "Error: Ya existe un detalle de expensa para la UF 9 en la Expensa 6."
-- RETURN = -4

--------------------------------------------------
---- MODIFICAR DETALLE EXPENSA ----

------ 1. CASO EXITOSO (Modificar DE ID: 2) ------
EXEC consorcio.sp_modificarDetalleExpensa
    @idDetalleExpensa = 2, -- ID 2, NO pagado
    @fechaSegundoVenc = '2025-08-25', @interesPorMora = 10.00, @totalAPagar = 610.00;

-- Resultado esperado:
-- PRINT: "Detalle de Expensa con ID: 2 modificado con exito."
-- RETURN = 0

------ 2. ERROR: No se puede modificar detalle ya pagado (DE ID: 3) ------
EXEC consorcio.sp_modificarDetalleExpensa
    @idDetalleExpensa = 3, -- ID 3, PAGADO con idPago = 1
    @interesPorMora = 1.00;

-- Resultado esperado:
-- RAISERROR: "Error: No se puede modificar el detalle de expensa ID 3. Ya tiene un pago asociado."
-- RETURN = -2

--------------------------------------------------
---- ELIMINAR DETALLE EXPENSA ----

------ 1. CASO EXITOSO (Eliminar DE ID: 4) ------
EXEC consorcio.sp_eliminarDetalleExpensa
    @idDetalleExpensa = 4;

-- Resultado esperado:
-- PRINT: "Detalle de Expensa con ID: 4 eliminado con exito."
-- RETURN = 0

------ 2. ERROR: No se puede eliminar detalle ya pagado (DE ID: 3) ------
EXEC consorcio.sp_eliminarDetalleExpensa
    @idDetalleExpensa = 3;

-- Resultado esperado:
-- RAISERROR: "Error: La factura ID 3 ya esta pagada (asociada al Pago ID 1). No se puede eliminar."
-- RETURN = -2

--------------------------------------------------
-- **** TESTING PAGO ****
--------------------------------------------------

---- INSERTAR PAGO ----
-- Detalle Expensa 2 está sin pagar y con TotalA pagar de 610.00

------ 1. CASO EXITOSO (PAGO ID: 2, asociado a Detalle 2) ------
EXEC consorcio.sp_insertarPago
    @idDetalleExpensa = 2, -- DE ID 2
    @monto = 610.00,
    @fecha = '2025-08-05';

-- Resultado esperado:
-- PRINT: "Pago insertado con exito con ID: 2"
-- RETURN = 0
-- Nota: La lógica de negocio debería actualizar el campo idPago en detalle_expensa 2 con el valor 2.

------ 4. ERROR: Detalle Expensa ya pagado ------
-- Intentar pagar el Detalle 2 nuevamente (ya pagado por Pago 2)
EXEC consorcio.sp_insertarPago
    @idDetalleExpensa = 2,
    @monto = 610.00,
    @fecha = '2025-08-06';

-- Resultado esperado:
-- RAISERROR: "Error: El detalle de expensa ID 2 ya tiene un pago asociado (Pago ID 2)."
-- RETURN = -3

---- MODIFICAR PAGO ----
-- Preparación: Pago 3 para modificar (sin asociar a Detalle Expensa)
EXEC consorcio.sp_insertarPago
    @idDetalleExpensa = NULL, @monto = 100.00, @fecha = '2025-08-01'; -- PAGO ID: 3

------ 1. CASO EXITOSO (Modificar monto de PAGO ID: 3) ------
EXEC consorcio.sp_modificarPago
    @idPago = 3,
    @importe = 150.00;

-- Resultado esperado:
-- PRINT: "Pago con ID: 3 modificado con exito."
-- RETURN = 0

------ 3. ERROR: Pago ya usado para pagar una factura (Bloqueo - PAGO ID: 2) ------
EXEC consorcio.sp_modificarPago
    @idPago = 2, -- ID 2, asociado a Detalle Expensa 2
    @importe = 6000.00;

-- Resultado esperado:
-- RAISERROR: "Error: El pago ID 2 ya fue utilizado para pagar una factura. No se puede modificar."
-- RETURN = -2

---- ELIMINAR PAGO ----
-- Pago 3 está sin asociar.
-- Pago 2 está asociado a Detalle Expensa 2.

------ 1. CASO EXITOSO (Eliminar PAGO ID: 3) ------
EXEC consorcio.sp_eliminarPago
    @idPago = 3;

-- Resultado esperado:
-- PRINT: "Pago con ID: 3 eliminado con exito."
-- RETURN = 0

------ 3. ERROR: Pago usado en expensa (Bloqueo - PAGO ID: 2) ------
EXEC consorcio.sp_eliminarPago
    @idPago = 2;

-- Resultado esperado:
-- RAISERROR: "Error: El pago ID 2 ya fue utilizado para pagar una factura. No se puede eliminar."
-- RETURN = -2