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
Enunciado:        "03 - Creación de Procedimientos Almacenados ABMs"
================================================================================
*/

USE Com2900G08;
GO

--ABM PERSONA

-------------------
--INSERTAR PERSONA
-------------------
CREATE OR ALTER PROCEDURE consorcio.sp_insertarPersona
(
    @nombre VARCHAR(50),
    @apellido VARCHAR(50),
    @dni int,
    @email VARCHAR(100) = NULL, --le ponemos x default el null para q no de problemas despues si no se asigna algun mail o telefono
    @telefono VARCHAR(20) = NULL,
    @cuentaOrigen CHAR(22),
    @idPersonaCreada INT = NULL OUTPUT --Lo vamos a usar cuando queramos cargar la tabla de personaUF
)
AS
BEGIN
    SET NOCOUNT ON;

    --Validamos que no se inserte alguien con el mismo dni.
    IF EXISTS (SELECT 1 FROM consorcio.persona WHERE dni = @dni)
    BEGIN
        RAISERROR('Error: Este dni ya se encuentra registrado.', 16, 1);
        RETURN -1;
    END

    --Validamos q la cuenta origen sea numerica.
    IF ISNUMERIC(@cuentaOrigen) = 0
    BEGIN
        RAISERROR('Error: La cuenta origen debe ser numérica.', 16, 1);
        RETURN -2;
    END

    --Hacemos la insercion
    BEGIN TRY
        INSERT INTO consorcio.persona(nombre, apellido, dni, email, telefono, cuentaOrigen)
        VALUES (@nombre, @apellido, @dni, @email, @telefono, @cuentaOrigen);

        SELECT @idPersonaCreada = SCOPE_IDENTITY();
        
        PRINT 'Persona insertada con id: ' + CAST(@idPersonaCreada AS VARCHAR);

        RETURN 0;
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR('Error inesperado al insertar persona: %s', 16, 1, @ErrorMessage);
        RETURN -3;
    END CATCH

    SET NOCOUNT OFF;
END;
GO

--------------------
--MODIFICAR PERSONA
--------------------
CREATE OR ALTER PROCEDURE consorcio.sp_modificarPersona
(
    @idPersona int, --a quien vamos a modificar

    @nombre VARCHAR(50) = NULL,
    @apellido VARCHAR(50) = NULL,
    @dni INT = NULL,
    @email VARCHAR(100) = NULL,
    @telefono VARCHAR(20) = NULL,
    @cuentaOrigen CHAR(22) = NULL --x default los ponemos todos null, entonces si algun campo no se quiere cambiar no se cambia
)
AS
BEGIN
    SET NOCOUNT ON;
    
    --Validamos q exista la persona a modificar
    IF NOT EXISTS (SELECT 1 FROM consorcio.persona WHERE idPersona = @idPersona) BEGIN
        RAISERROR ('Error: La persona a modificar no existe.', 16, 1);
        RETURN -1;
    END

    --Validamos q en caso de que quieran modificar el dni de alguien, este dni no le pertenezca a otra persona
    IF @dni IS NOT NULL AND EXISTS (SELECT 1 FROM consorcio.persona 
                                    WHERE dni = @dni AND idPersona <> @idPersona)
    BEGIN
        RAISERROR('Error: El nuevo dni ya le pertenece a otra persona.', 16, 1);
        RETURN -2; 
    END

    --Validamos q si pasaron una nueva cuentaOrigen sea numerica
    IF @cuentaOrigen IS NOT NULL AND ISNUMERIC(@cuentaOrigen) = 0
    BEGIN
        RAISERROR('Error: La nueva cuenta origen debe ser numerica.', 16, 1);
        RETURN -3;
    END

    --Ahora pasamos a la actualizacion

    BEGIN TRY
        UPDATE consorcio.persona
        SET 
            nombre = ISNULL(@nombre, nombre), --Si la variable es null, se queda con lo q ya tenia, sino se actualiza con lo enviado
            apellido = ISNULL(@apellido, apellido),
            dni = ISNULL(@dni, dni),
            email = ISNULL(@email, email),
            telefono = ISNULL(@telefono, telefono),
            cuentaOrigen = ISNULL(@cuentaOrigen, cuentaOrigen)
        WHERE idPersona = @idPersona;

        PRINT 'Persona con ID ' + CAST(@idPersona AS VARCHAR) + ' modificada exitosamente.';
        RETURN 0;
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR('Error inesperado al modificar la persona: %s', 16, 1, @ErrorMessage);
        RETURN -4;
    END CATCH

    SET NOCOUNT OFF;
END;
GO

--------------------
--ELIMINAR PERSONA
--------------------
CREATE OR ALTER PROCEDURE consorcio.sp_eliminarPersona
(
    @idPersona int
)
AS
BEGIN
    SET NOCOUNT ON;

    --validamos que exista la persona a eliminar
    IF NOT EXISTS (SELECT 1 FROM consorcio.persona WHERE idPersona = @idPersona) BEGIN
        RAISERROR ('Error: La persona a eliminar no existe.', 16, 1);
        RETURN -1;
    END

    --validamos que no este ya dada de baja
    IF EXISTS (SELECT 1 FROM consorcio.persona WHERE idPersona = @idPersona AND fechaBaja IS NOT NULL)
    BEGIN
        RAISERROR ('Advertencia: La persona ya se encontraba dada de baja.', 10, 1); --aca va 10 en lugar de 16 pq el 10 es para advertencias sin detener el script
        RETURN 0; --como es advertencia y no error devuelvo 0
    END

    BEGIN TRY
        UPDATE consorcio.persona
        SET 
            fechaBaja = GETDATE() --le asignamos la fecha actual
        WHERE 
            idPersona = @idPersona;

        PRINT 'Persona con ID ' + CAST(@idPersona AS VARCHAR) + ' dada de baja exitosamente.';
        RETURN 0;
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR('Error inesperado al eliminar la persona: %s', 16, 1, @ErrorMessage);
        RETURN -2;
    END CATCH

    SET NOCOUNT OFF;
END;
GO

--ABM PERSONA UNIDAD FUNCIONAL

------------------------------------
--INSERTAR PERSONA UNIDAD FUNCIONAL
------------------------------------
CREATE OR ALTER PROCEDURE consorcio.sp_insertarPersonaUF
(
    @idPersona INT,
    @idUnidadFuncional INT,
    @rol VARCHAR(15)
)
AS
BEGIN
    SET NOCOUNT ON;

    --validamos que la persona exista y NO este dada de baja
    IF NOT EXISTS (SELECT 1 FROM consorcio.persona 
                   WHERE idPersona = @idPersona AND fechaBaja IS NULL)
    BEGIN
        RAISERROR('Error: La persona (ID: %d) no existe o esta dada de baja.', 16, 1, @idPersona);
        RETURN -1;
    END


    --validamos que la UF exista y no este dada de baja
    IF NOT EXISTS (SELECT 1 FROM consorcio.unidad_funcional 
                   WHERE idUnidadFuncional = @idUnidadFuncional
                     AND fechaBaja IS NULL)
    BEGIN
        RAISERROR('Error: La unidad funcional no existe o esta dada de baja.', 16, 1);
        RETURN -2;
    END

    -- validamos el rol
    IF LOWER(@rol) NOT IN ('propietario', 'inquilino')
    BEGIN
        RAISERROR('Error: El rol no es valido. Puede ser "propietario" o "inquilino".', 16, 1);
        RETURN -3;
    END

    -- Validamos que el rol no este ya ocupado en esa UF
    IF EXISTS (SELECT 1 FROM consorcio.persona_unidad_funcional 
               WHERE idUnidadFuncional = @idUnidadFuncional 
                 AND rol = LOWER(@rol))
    BEGIN
        RAISERROR('Error: Ya existe una persona asignada al rol en la UF. Use el SP de modificar.', 16, 1);
        RETURN -4; 
    END

    BEGIN TRY
        INSERT INTO consorcio.persona_unidad_funcional (
            idUnidadFuncional, 
            rol, 
            idPersona
        )
        VALUES (
            @idUnidadFuncional, 
            LOWER(@rol), 
            @idPersona
        );
        
        PRINT 'Persona y UF relacionadas correctamente';
        RETURN 0;

    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR('Error inesperado al relacionar persona con UF: %s', 16, 1, @ErrorMessage);
        RETURN -5;
    END CATCH

    SET NOCOUNT OFF;
END;
GO

-------------------------------------
--MODIFICAR PERSONA UNIDAD FUNCIONAL
-------------------------------------
CREATE OR ALTER PROCEDURE consorcio.sp_modificarPersonaUF
(
    @idUnidadFuncional INT,
    @rol VARCHAR(15),
    @idNuevaPersona INT
)
AS
BEGIN
    SET NOCOUNT ON;

    --validamos q la persona nueva exista y no este dada de baja
    IF NOT EXISTS (SELECT 1 FROM consorcio.persona 
                   WHERE idPersona = @idNuevaPersona AND fechaBaja IS NULL)
    BEGIN
        RAISERROR('Error: La nueva persona no existe o esta dada de baja.', 16, 1, @idNuevaPersona);
        RETURN -1;
    END

    --validamos q el rol sea valido
    IF LOWER(@rol) NOT IN ('propietario', 'inquilino')
    BEGIN
        RAISERROR('Error: El rol no es valido. Puede ser "propietario" o "inquilino".', 16, 1);
        RETURN -2;
    END

    -- Validamos que la UF exista y este activa
    IF NOT EXISTS (SELECT 1 FROM consorcio.unidad_funcional 
                   WHERE idUnidadFuncional = @idUnidadFuncional
                     AND fechaBaja IS NULL)
    BEGIN
        RAISERROR('Error: La Unidad Funcional no existe o esta dada de baja. No se puede modificar.', 16, 1);
        RETURN -3;
    END

    -- validamos q la UF exista y tenga el rol que queremos modificar ya asignado
    IF NOT EXISTS (SELECT 1 FROM consorcio.persona_unidad_funcional 
                   WHERE idUnidadFuncional = @idUnidadFuncional 
                     AND rol = LOWER(@rol))
    BEGIN
        RAISERROR('Error: No existe un %s asignado a la UF. (Use el SP de insertar en su lugar).', 16, 1, @rol);
        RETURN -4;
    END

    BEGIN TRY
        UPDATE consorcio.persona_unidad_funcional
        SET 
            idPersona = @idNuevaPersona --asignamos nueva persona a la relacion
        WHERE 
            idUnidadFuncional = @idUnidadFuncional
            AND rol = LOWER(@rol); --especif para el rol q se pidio

        PRINT 'Modificacion realizada en la UF con exito.';
        RETURN 0;

    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR('Error inesperado al modificar la relacion: %s', 16, 1, @ErrorMessage);
        RETURN -100;
    END CATCH

    SET NOCOUNT OFF;
END;
GO

-------------------------------------
--ELIMINAR PERSONA UNIDAD FUNCIONAL
-------------------------------------
CREATE OR ALTER PROCEDURE consorcio.sp_eliminarPersonaUF
(
    @idUnidadFuncional INT,
    @rol VARCHAR(15)
)
AS
BEGIN
    SET NOCOUNT ON;

    --validamos al rol
    IF LOWER(@rol) NOT IN ('propietario', 'inquilino')
    BEGIN
        RAISERROR('Error: El rol no es valido. Debe ser "propietario" o "inquilino".', 16, 1);
        RETURN -1;
    END

    --validamos q el rol q queremos eliminar exista en la UF deseada
    IF NOT EXISTS (SELECT 1 FROM consorcio.persona_unidad_funcional 
                   WHERE idUnidadFuncional = @idUnidadFuncional 
                     AND rol = LOWER(@rol))
    BEGIN
        RAISERROR('Error: No existe un %s asignado a la UF.', 16, 1, @rol);
        RETURN -2;
    END

    BEGIN TRY
        DELETE FROM consorcio.persona_unidad_funcional
        WHERE 
            idUnidadFuncional = @idUnidadFuncional
            AND rol = LOWER(@rol);

        PRINT 'Eliminacion realizada con exito';
        RETURN 0;

    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR('Error inesperado al eliminar la relación: %s', 16, 1, @ErrorMessage);
        RETURN -3;
    END CATCH

    SET NOCOUNT OFF;
END;
GO

--ABM UNIDAD FUNCIONAL

---------------------------
--INSERTAR UNIDAD FUNCIONAL
---------------------------
CREATE OR ALTER PROCEDURE consorcio.sp_insertarUnidadFuncional
(
    @idConsorcio INT,
    @cuentaOrigen VARCHAR(22),
    @numeroUnidadFuncional INT,
    @piso CHAR(2),
    @departamento CHAR(1),
    @coeficiente DECIMAL(5,2),
    @metrosCuadrados INT,
    @idUFCreada INT = NULL OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;

    -- validamos q el consorcio al que le queremos insertar una UF exista
    IF NOT EXISTS (SELECT 1 FROM consorcio.consorcio 
                   WHERE idConsorcio = @idConsorcio)
    BEGIN
        RAISERROR('Error: El consorcio no existe.', 16, 1);
        RETURN -1;
    END

    -- validamos q no exista otra UF activa con el mismo numero en el consorcio
    IF EXISTS (SELECT 1 FROM consorcio.unidad_funcional 
               WHERE idConsorcio = @idConsorcio 
                 AND numeroUnidadFuncional = @numeroUnidadFuncional
                 AND FechaBaja IS NULL)
    BEGIN
        RAISERROR('Error: Ya existe una UF ACTIVA con el numero indicado en este consorcio.', 16, 1);
        RETURN -2;
    END

    -- validamos que la cuenta origen sea numerica
    IF @cuentaOrigen IS NOT NULL AND ISNUMERIC(@cuentaOrigen) = 0
    BEGIN
        RAISERROR('Error: La cuenta origen debe ser numerica.', 16, 1);
        RETURN -3;
    END

    -- validamos coeficiente
    IF @coeficiente <= 0 OR @coeficiente > 100
    BEGIN
        RAISERROR('Error: El coeficiente debe ser un valor entre 0,01 y 100,00.', 16, 1);
        RETURN -4;
    END

    -- validamos los metros cuadrados
    IF @metrosCuadrados <= 0
    BEGIN
        RAISERROR('Error: Los metros cuadrados deben ser un valor positivo.', 16, 1);
        RETURN -5;
    END

    BEGIN TRY
        INSERT INTO consorcio.unidad_funcional (
            idConsorcio,
            cuentaOrigen,
            numeroUnidadFuncional,
            piso,
            departamento,
            coeficiente,
            metrosCuadrados
        )
        VALUES (
            @idConsorcio,
            @cuentaOrigen,
            @numeroUnidadFuncional,
            @piso,
            @departamento,
            @coeficiente,
            @metrosCuadrados
        );

        -- Obtener el ID creado
        SELECT @idUFCreada = SCOPE_IDENTITY();
        
        PRINT 'Unidad Funcional insertada con ID: ' + CAST(@idUFCreada AS VARCHAR);
        RETURN 0;
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR('Error inesperado al insertar la Unidad Funcional: %s', 16, 1, @ErrorMessage);
        RETURN -6;
    END CATCH

    SET NOCOUNT OFF;
END;
GO

----------------------------
--MODIFICAR UNIDAD FUNCIONAL
----------------------------
CREATE OR ALTER PROCEDURE consorcio.sp_modificarUnidadFuncional
(
    @idUnidadFuncional INT,
    @idConsorcio INT = NULL,
    @cuentaOrigen VARCHAR(22) = NULL,
    @numeroUnidadFuncional INT = NULL,
    @piso CHAR(2) = NULL,
    @coeficiente DECIMAL(5,2) = NULL,
    @metrosCuadrados INT = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    -- validamos q exista la uf a modificar y q este activa
    IF NOT EXISTS (SELECT 1 FROM consorcio.unidad_funcional 
                   WHERE idUnidadFuncional = @idUnidadFuncional
                     AND fechaBaja IS NULL)
    BEGIN
        RAISERROR('Error: La Unidad Funcional a modificar no existe o esta dada de baja.', 16, 1);
        RETURN -1;
    END

    -- validar q en caso de q se modifique el consorcio, sea por uno que exista
    IF @idConsorcio IS NOT NULL AND NOT EXISTS (SELECT 1 FROM consorcio.consorcio 
                                               WHERE idConsorcio = @idConsorcio)
    BEGIN
        RAISERROR('Error: El nuevo consorcio no existe.', 16, 1);
        RETURN -2;
    END

    -- validar duplicados del numero de UF en el consorcio destino
    IF @numeroUnidadFuncional IS NOT NULL
    BEGIN
        DECLARE @targetConsorcioID INT;
        SELECT @targetConsorcioID = ISNULL(@idConsorcio, idConsorcio) 
        FROM consorcio.unidad_funcional 
        WHERE idUnidadFuncional = @idUnidadFuncional;

        -- buscamos si el nro UF ya esta usado por otra UF activa
        IF EXISTS (SELECT 1 FROM consorcio.unidad_funcional 
                   WHERE idConsorcio = @targetConsorcioID 
                     AND numeroUnidadFuncional = @numeroUnidadFuncional
                     AND idUnidadFuncional <> @idUnidadFuncional
                     AND fechaBaja IS NULL)
        BEGIN
            RAISERROR('Error: El numero de UF ya esta usado por otra UF activa en el consorcio destino.', 16, 1);
            RETURN -3;
        END
    END

    -- validar cuenta origen
    IF @cuentaOrigen IS NOT NULL AND ISNUMERIC(@cuentaOrigen) = 0
    BEGIN
        RAISERROR('Error: La nueva cuenta origen debe ser numerica.', 16, 1);
        RETURN -4;
    END

    -- validar coeficiente
    IF @coeficiente IS NOT NULL AND (@coeficiente <= 0 OR @coeficiente > 100)
    BEGIN
        RAISERROR('Error: El nuevo coeficiente debe ser un valor entre 0,01 y 100,00.', 16, 1);
        RETURN -5;
    END

    -- validar m2
    IF @metrosCuadrados IS NOT NULL AND @metrosCuadrados <= 0
    BEGIN
        RAISERROR('Error: Los nuevos metros cuadrados deben ser un valor positivo.', 16, 1);
        RETURN -6;
    END

    BEGIN TRY
        UPDATE consorcio.unidad_funcional
        SET 
            idConsorcio = ISNULL(@idConsorcio, idConsorcio),
            cuentaOrigen = ISNULL(@cuentaOrigen, cuentaOrigen),
            numeroUnidadFuncional = ISNULL(@numeroUnidadFuncional, numeroUnidadFuncional),
            piso = ISNULL(@piso, piso),
            coeficiente = ISNULL(@coeficiente, coeficiente),
            metrosCuadrados = ISNULL(@metrosCuadrados, metrosCuadrados)
        WHERE
            idUnidadFuncional = @idUnidadFuncional;

        PRINT 'Unidad Funcional modificada exitosamente.';
        RETURN 0;

    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR('Error inesperado al modificar la Unidad Funcional: %s', 16, 1, @ErrorMessage);
        RETURN -7;
    END CATCH

    SET NOCOUNT OFF;
END;
GO

---------------------------
--ELIMINAR UNIDAD FUNCIONAL
---------------------------
CREATE OR ALTER PROCEDURE consorcio.sp_eliminarUnidadFuncional
(
    @idUnidadFuncional INT
)
AS
BEGIN
    SET NOCOUNT ON;

    -- validar que la UF exista y este activa
    IF NOT EXISTS (SELECT 1 FROM consorcio.unidad_funcional 
                   WHERE idUnidadFuncional = @idUnidadFuncional
                     AND fechaBaja IS NULL)
    BEGIN
        RAISERROR('Error: La Unidad Funcional no existe o ya esta dada de baja.', 16, 1);
        RETURN -1;
    END

    -- validar que no este ocupada
    -- (El usuario debera llamar a sp_eliminarPersonaUF primero)
    IF EXISTS (SELECT 1 FROM consorcio.persona_unidad_funcional 
               WHERE idUnidadFuncional = @idUnidadFuncional)
    BEGIN
        RAISERROR('Error: No se puede dar de baja la UF. Ya que tiene propietarios o inquilinos asignados.', 16, 1);
        RETURN -2;
    END

    -- validar que no tenga cocheras asociadas
    -- (El usuario debera eliminar la cochera primero)
    IF EXISTS (SELECT 1 FROM consorcio.cochera 
               WHERE idUnidadFuncional = @idUnidadFuncional)
    BEGIN
        RAISERROR('Error: No se puede dar de baja la UF. Ya que tiene cocheras asociadas.', 16, 1);
        RETURN -3;
    END

    -- validar que no tenga bauleras asociadas
    -- (El usuario debera eliminar la baulera primero)
    IF EXISTS (SELECT 1 FROM consorcio.baulera 
               WHERE idUnidadFuncional = @idUnidadFuncional)
    BEGIN
        RAISERROR('Error: No se puede dar de baja la UF. Ya que tiene bauleras asociadas.', 16, 1);
        RETURN -4;
    END

    BEGIN TRY
        UPDATE consorcio.unidad_funcional
        SET 
            fechaBaja = GETDATE() -- Le asigna la fecha en la q se dio de baja
        WHERE
            idUnidadFuncional = @idUnidadFuncional;

        PRINT 'Unidad Funcional dada de baja exitosamente.';
        RETURN 0;

    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR('Error inesperado al dar de baja la Unidad Funcional: %s', 16, 1, @ErrorMessage);
        RETURN -5;
    END CATCH

    SET NOCOUNT OFF;
END;
GO

--ABM CONSORCIO

--------------------
--INSERTAR CONSORCIO
--------------------
CREATE OR ALTER PROCEDURE consorcio.sp_insertarConsorcio
    @idConsorcio INT,
    @nombre VARCHAR(20),
    @direccion VARCHAR(20),
    @cantidadUnidadesFuncionales INT,
    @metrosCuadradosTotales INT
AS
BEGIN
    SET NOCOUNT ON;

    -- validamos q no exista un consorcio activo con el mismo id
    IF EXISTS (SELECT 1 FROM consorcio.consorcio 
               WHERE idConsorcio = @idConsorcio 
               AND fechaBaja IS NULL)
    BEGIN
        RAISERROR('Error: Ya existe un consorcio activo con ese ID.', 16, 1);
        RETURN -1;
    END

    -- validamos la cant de uf
    IF @cantidadUnidadesFuncionales <= 0
    BEGIN
        RAISERROR('Error: La cantidad de unidades funcionales debe ser mayor a 0.', 16, 1);
        RETURN -3;
    END

    -- validamos la cant de m2
    IF @metrosCuadradosTotales <= 0
    BEGIN
        RAISERROR('Error: Los metros cuadrados totales deben ser mayores a 0.', 16, 1);
        RETURN -4;
    END

    BEGIN TRY
        
        -- Verificamos si el ID existe sabemos que si existe, esta inactivo por la validacion de antes
        IF EXISTS (SELECT 1 FROM consorcio.consorcio WHERE idConsorcio = @idConsorcio)
        BEGIN
            -- caso q exista pero este de baja
            UPDATE consorcio.consorcio
            SET 
                nombre = @nombre,
                direccion = @direccion,
                cantidadUnidadesFuncionales = @cantidadUnidadesFuncionales,
                metrosCuadradosTotales = @metrosCuadradosTotales,
                fechaBaja = NULL
            WHERE 
                idConsorcio = @idConsorcio;

            PRINT 'Consorcio con ID: ' + CAST(@idConsorcio AS VARCHAR) + ' ha sido reactivado con exito.';
        END
        ELSE
        BEGIN
            -- caso nuevo
            INSERT INTO consorcio.consorcio (
                idConsorcio,
                nombre,
                direccion,
                cantidadUnidadesFuncionales,
                metrosCuadradosTotales,
                fechaBaja
            )
            VALUES (
                @idConsorcio,
                @nombre,
                @direccion,
                @cantidadUnidadesFuncionales,
                @metrosCuadradosTotales,
                NULL
            );

            PRINT 'Consorcio NUEVO insertado con éxito con ID: ' + CAST(@idConsorcio AS VARCHAR);
        END
        
        RETURN 0;

    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR('Error inesperado al insertar/reactivar el consorcio: %s', 16, 1, @ErrorMessage);
        RETURN -5;
    END CATCH

    SET NOCOUNT OFF;
END;
GO

---------------------
--MODIFICAR CONSORCIO
---------------------
CREATE OR ALTER PROCEDURE consorcio.sp_modificarConsorcio
    @idConsorcio INT,
    @nombre VARCHAR(20) = NULL,
    @direccion VARCHAR(20) = NULL,
    @cantidadUnidadesFuncionales INT = NULL,
    @metrosCuadradosTotales INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- validamos q exista el consorcio y este activo
    IF NOT EXISTS (SELECT 1 FROM consorcio.consorcio 
                   WHERE idConsorcio = @idConsorcio 
                   AND fechaBaja IS NULL)
    BEGIN
        RAISERROR('Error: El consorcio no existe o esta dado de baja. No se puede modificar.', 16, 1);
        RETURN -1;
    END

    -- 2. validamos direccion
    IF @direccion IS NOT NULL AND @direccion = ''
    BEGIN
        RAISERROR('Error: La direccion no puede ser una cadena vacia.', 16, 1);
        RETURN -2;
    END

    -- 3. validamos la cant de UF
    IF @cantidadUnidadesFuncionales IS NOT NULL AND @cantidadUnidadesFuncionales <= 0
    BEGIN
        RAISERROR('Error: La cantidad de unidades funcionales debe ser mayor a 0.', 16, 1);
        RETURN -3;
    END

    -- 4. validamos la cant de M2
    IF @metrosCuadradosTotales IS NOT NULL AND @metrosCuadradosTotales <= 0
    BEGIN
        RAISERROR('Error: Los metros cuadrados totales deben ser mayores a 0.', 16, 1);
        RETURN -4;
    END

    BEGIN TRY
        UPDATE consorcio.consorcio
        SET
            nombre = ISNULL(@nombre, nombre),
            direccion = ISNULL(@direccion, direccion),
            cantidadUnidadesFuncionales = ISNULL(@cantidadUnidadesFuncionales, cantidadUnidadesFuncionales),
            metrosCuadradosTotales = ISNULL(@metrosCuadradosTotales, metrosCuadradosTotales)
        WHERE
            idConsorcio = @idConsorcio;

        PRINT 'Consorcio con ID: ' + CAST(@idConsorcio AS VARCHAR) + ' actualizado con exito.';
        RETURN 0;

    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR('Error inesperado al actualizar el consorcio: %s', 16, 1, @ErrorMessage);
        RETURN -5;
    END CATCH

    SET NOCOUNT OFF;
END;
GO

---------------------
--ELIMINAR CONSORCIO
---------------------
CREATE OR ALTER PROCEDURE consorcio.sp_eliminarConsorcio
    @idConsorcio INT
AS
BEGIN
    SET NOCOUNT ON;

    -- validamos q el consorcio exista y este activo
    IF NOT EXISTS (SELECT 1 FROM consorcio.consorcio 
                   WHERE idConsorcio = @idConsorcio 
                   AND fechaBaja IS NULL)
    BEGIN
        RAISERROR('Error: El consorcio no existe o ya esta dado de baja.', 16, 1);
        RETURN -1;
    END

    -- validamos q el consorcio no tenga UF linkeadas activas
    IF EXISTS (SELECT 1 FROM consorcio.UnidadFuncional 
               WHERE idConsorcio = @idConsorcio 
               AND fechaBaja IS NULL)
    BEGIN
        RAISERROR('Error: No se puede dar de baja el consorcio. Ya que tiene UF activas asociadas.', 16, 1);
        RETURN -2;
    END

    BEGIN TRY
        UPDATE consorcio.consorcio
        SET
            fechaBaja = GETDATE() -- asignamos la fecha en la se ejecuta a la fechaBaja
        WHERE
            idConsorcio = @idConsorcio;

        PRINT 'Consorcio con ID: ' + CAST(@idConsorcio AS VARCHAR) + ' dado de baja con exito.';
        RETURN 0;

    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR('Error inesperado al dar de baja el consorcio: %s', 16, 1, @ErrorMessage);
        RETURN -3;
    END CATCH

    SET NOCOUNT OFF;
END;
GO

--ABM Estado Financiero

----------------------------
--INSERTAR ESTADO FINANCIERO
----------------------------
CREATE OR ALTER PROCEDURE consorcio.sp_insertarEstadoFinanciero
    @idConsorcio INT,
    @periodo VARCHAR(12),
    @anio INT,
    @saldoAnterior DECIMAL(12,2) = NULL,
    @ingresosEnTermino DECIMAL(12,2) = NULL,
    @ingresosAdeudados DECIMAL(12,2) = NULL,
    @egresos DECIMAL(12,2) = NULL,
    @saldoCierre DECIMAL(12,2) = NULL,
    @idEstadoFinancieroCreado INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- validamos q exista el consorcio y no este dado de baja
    IF NOT EXISTS (SELECT 1 FROM consorcio.consorcio 
                   WHERE idConsorcio = @idConsorcio AND fechaBaja IS NULL)
    BEGIN
        RAISERROR('Error: El consorcio no existe o esta dado de baja.', 16, 1);
        RETURN -1;
    END

    -- validamos el periodo
    IF LOWER(@periodo) NOT IN ('enero','febrero','marzo','abril','mayo','junio','julio','agosto','septiembre','octubre','noviembre','diciembre')
    BEGIN
        RAISERROR('Error: El periodo no es valido. Debe ser un mes.', 16, 1);
        RETURN -2;
    END

    -- validamos q haya un solo estado financiero para un consorcio en un periodo y año especifico
    IF EXISTS (SELECT 1 FROM consorcio.estado_financiero 
               WHERE idConsorcio = @idConsorcio 
               AND periodo = LOWER(@periodo)
               AND anio = @anio)
    BEGIN
        RAISERROR('Error: Ya existe un estado financiero para el Consorcio %d en el período %s del año %d.', 16, 1, @idConsorcio, @periodo, @anio);
        RETURN -3;
    END

    -- validaciones de valores
    IF (@ingresosEnTermino IS NOT NULL AND @ingresosEnTermino < 0) OR
       (@ingresosAdeudados IS NOT NULL AND @ingresosAdeudados < 0) OR
       (@egresos IS NOT NULL AND @egresos < 0)
    BEGIN
        RAISERROR('Error: Los montos de ingresos y egresos no pueden ser negativos.', 16, 1);
        RETURN -4;
    END

    BEGIN TRY
        INSERT INTO consorcio.estado_financiero (
            idConsorcio,
            periodo,
            anio,
            saldoAnterior,
            ingresosEnTermino,
            ingresosAdeudados,
            egresos,
            saldoCierre
        )
        VALUES (
            @idConsorcio,
            LOWER(@periodo),
            @anio,
            @saldoAnterior,
            @ingresosEnTermino,
            @ingresosAdeudados,
            @egresos,
            @saldoCierre
        );

        SELECT @idEstadoFinancieroCreado = SCOPE_IDENTITY();
        
        PRINT 'Estado Financiero insertado con exito con ID: ' + CAST(@idEstadoFinancieroCreado AS VARCHAR);
        RETURN 0;

    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR('Error inesperado al insertar el estado financiero: %s', 16, 1, @ErrorMessage);
        RETURN -5;
    END CATCH

    SET NOCOUNT OFF;
END;
GO

-----------------------------
--MODIFICAR ESTADO FINANCIERO
-----------------------------
CREATE OR ALTER PROCEDURE consorcio.sp_modificarEstadoFinanciero
    @idEstadoFinanciero INT, -- id a modif
    @idConsorcio INT = NULL, 
    @periodo VARCHAR(12) = NULL,
    @anio INT = NULL,
    @saldoAnterior DECIMAL(12,2) = NULL,
    @ingresosEnTermino DECIMAL(12,2) = NULL,
    @ingresosAdeudados DECIMAL(12,2) = NULL,
    @egresos DECIMAL(12,2) = NULL,
    @saldoCierre DECIMAL(12,2) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- Validamos que exista ese estado financiero
    IF NOT EXISTS (SELECT 1 FROM consorcio.estado_financiero WHERE idEstadoFinanciero = @idEstadoFinanciero)
    BEGIN
        RAISERROR('Error: El estado financiero ID %d no existe. No se puede modificar.', 16, 1, @idEstadoFinanciero);
        RETURN -1;
    END

    -- Validamos que el nuevo consorcio (si se quiere modif) exista y este activo
    IF @idConsorcio IS NOT NULL AND NOT EXISTS (SELECT 1 FROM consorcio.consorcio 
                                                WHERE idConsorcio = @idConsorcio AND fechaBaja IS NULL)
    BEGIN
        RAISERROR('Error: El nuevo consorcio no existe o esta dado de baja.', 16, 1);
        RETURN -2;
    END

    -- Validamos el periodo
    IF @periodo IS NOT NULL AND LOWER(@periodo) NOT IN ('enero','febrero','marzo','abril','mayo','junio','julio','agosto','septiembre','octubre','noviembre','diciembre')
    BEGIN
        RAISERROR('Error: El periodo no es valido. Debe ser un mes.', 16, 1);
        RETURN -3;
    END

    -- validaciones para evitar duplicados
    IF @idConsorcio IS NOT NULL OR @periodo IS NOT NULL OR @anio IS NOT NULL
    BEGIN
        DECLARE @targetConsorcio INT, @targetPeriodo VARCHAR(12), @targetAnio INT;
        
        SELECT @targetConsorcio = idConsorcio, @targetPeriodo = periodo, @targetAnio = anio
        FROM consorcio.estado_financiero
        WHERE idEstadoFinanciero = @idEstadoFinanciero;

        SET @targetConsorcio = ISNULL(@idConsorcio, @targetConsorcio);
        SET @targetPeriodo = ISNULL(LOWER(@periodo), @targetPeriodo);
        SET @targetAnio = ISNULL(@anio, @targetAnio);

        IF EXISTS (SELECT 1 FROM consorcio.estado_financiero
                   WHERE idConsorcio = @targetConsorcio 
                   AND periodo = @targetPeriodo
                    AND anio = @targetAnio
                   AND idEstadoFinanciero <> @idEstadoFinanciero)
        BEGIN
            RAISERROR('Error: La nueva combinacion (Consorcio %d, %s %d) ya existe en otro registro.', 16, 1, @targetConsorcio, @targetPeriodo, @targetAnio);
            RETURN -4;
        END
    END
    
    IF (@ingresosEnTermino IS NOT NULL AND @ingresosEnTermino < 0) OR
       (@ingresosAdeudados IS NOT NULL AND @ingresosAdeudados < 0) OR
       (@egresos IS NOT NULL AND @egresos < 0)
    BEGIN
        RAISERROR('Error: Los montos de ingresos y egresos no pueden ser negativos.', 16, 1);
        RETURN -5;
    END

    BEGIN TRY
        UPDATE consorcio.estado_financiero
        SET
            idConsorcio = ISNULL(@idConsorcio, idConsorcio),
            periodo = ISNULL(LOWER(@periodo), periodo),
            anio = ISNULL(@anio, anio),
            saldoAnterior = ISNULL(@saldoAnterior, saldoAnterior),
            ingresosEnTermino = ISNULL(@ingresosEnTermino, ingresosEnTermino),
            ingresosAdeudados = ISNULL(@ingresosAdeudados, ingresosAdeudados),
            egresos = ISNULL(@egresos, egresos),
            saldoCierre = ISNULL(@saldoCierre, saldoCierre)
        WHERE
            idEstadoFinanciero = @idEstadoFinanciero;

        PRINT 'Estado Financiero con ID: ' + CAST(@idEstadoFinanciero AS VARCHAR) + ' actualizado con exito.';
        RETURN 0;

    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR('Error inesperado al actualizar el estado financiero: %s', 16, 1, @ErrorMessage);
        RETURN -6;
    END CATCH

    SET NOCOUNT OFF;
END;
GO

----------------------------
--ELIMINAR ESTADO FINANCIERO
----------------------------
CREATE OR ALTER PROCEDURE consorcio.sp_eliminarEstadoFinanciero
    @idEstadoFinanciero INT
AS
BEGIN
    SET NOCOUNT ON;

    -- validamos q exista dicho estado financiero
    IF NOT EXISTS (SELECT 1 FROM consorcio.estado_financiero 
                   WHERE idEstadoFinanciero = @idEstadoFinanciero)
    BEGIN
        RAISERROR('Error: El estado financiero no existe. No se puede eliminar.', 16, 1);
        RETURN -1;
    END

    BEGIN TRY
        DELETE FROM consorcio.estado_financiero
        WHERE idEstadoFinanciero = @idEstadoFinanciero;

        PRINT 'Estado Financiero con ID: ' + CAST(@idEstadoFinanciero AS VARCHAR) + ' eliminado con exito.';
        RETURN 0;

    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR('Error inesperado al eliminar el estado financiero: %s', 16, 1, @ErrorMessage);
        RETURN -2;
    END CATCH

    SET NOCOUNT OFF;
END;
GO

--ABM PAGO

---------------
--INSERTAR PAGO
---------------
CREATE OR ALTER PROCEDURE consorcio.sp_insertarPago
    @idPago INT,
    @cuentaOrigen CHAR(22),
    @importe DECIMAL(13,3),
    @estaAsociado BIT,
    @fecha DATE = NULL -- lo ponemos como opcional, si no se ingresa usamos la actual
AS
BEGIN
    SET NOCOUNT ON;

    -- validar q no exista otro pago con el mismo id
    IF EXISTS (SELECT 1 FROM consorcio.pago WHERE idPago = @idPago)
    BEGIN
        RAISERROR('Error: Ya existe un pago con el ID indicado. No se puede duplicar.', 16, 1);
        RETURN -1;
    END

    -- validamos la cuentaOrigen
    IF @cuentaOrigen IS NULL OR @cuentaOrigen = ''
    BEGIN
        RAISERROR('Error: La cuenta de origen no puede ser nula o vacia.', 16, 1);
        RETURN -2;
    END
    IF ISNUMERIC(@cuentaOrigen) = 0
    BEGIN
        RAISERROR('Error: La cuenta de origen debe ser numerica.', 16, 1);
        RETURN -3;
    END

    -- validamos el importe
    IF @importe IS NULL OR @importe <= 0
    BEGIN
        RAISERROR('Error: El importe debe ser un valor mayor a 0.', 16, 1);
        RETURN -4;
    END

    -- validamos q se indique si esta asociado o no
    IF @estaAsociado IS NULL
    BEGIN
        RAISERROR('Error: Se debe especificar si el pago esta asociado (0 o 1).', 16, 1);
        RETURN -5;
    END

    BEGIN TRY
        INSERT INTO consorcio.pago (
            idPago,
            fecha,
            cuentaOrigen,
            importe,
            estaAsociado,
            idDetalleExpensa
        )
        VALUES (
            @idPago,
            ISNULL(@fecha, GETDATE()), -- Si la fecha es nula, usamos la del día
            @cuentaOrigen,
            @importe,
            @estaAsociado,
            NULL
        );

        PRINT 'Pago insertado con exito con ID: ' + CAST(@idPago AS VARCHAR);
        RETURN 0;

    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR('Error inesperado al insertar el pago: %s', 16, 1, @ErrorMessage);
        RETURN -6;
    END CATCH

    SET NOCOUNT OFF;
END;
GO

----------------
--MODIFICAR PAGO
----------------
CREATE OR ALTER PROCEDURE consorcio.sp_modificarPago
    @idPago INT, 
    @fecha DATE = NULL,
    @cuentaOrigen CHAR(22) = NULL,
    @importe DECIMAL(13,3) = NULL,
    @estaAsociado BIT = NULL,
    @idDetalleExpensa INT = NULL 
AS
BEGIN
    SET NOCOUNT ON;

    -- Validamos que el pago exista y capturamos su estado actual
    DECLARE @currentIdDetalleExpensa INT;
    DECLARE @estaAsociadoActual BIT;
    
    SELECT 
        @estaAsociadoActual = estaAsociado,
        @currentIdDetalleExpensa = idDetalleExpensa -- Capturamos el idDetalleExpensa actual
    FROM consorcio.pago 
    WHERE idPago = @idPago;

    IF @estaAsociadoActual IS NULL
    BEGIN
        RAISERROR('Error: El pago ID %d no existe. No se puede modificar.', 16, 1, @idPago);
        RETURN -1;
    END
    
    IF @currentIdDetalleExpensa IS NOT NULL
    BEGIN
        RAISERROR('Error: El pago ID %d ya fue utilizado y esta cerrado (asociado a la factura ID %d). No se puede modificar.', 16, 1, @idPago, @currentIdDetalleExpensa);
        RETURN -2;
    END

    -- Si nos pasan un idDetalleExpensa para asociar, validamos que exista
    IF @idDetalleExpensa IS NOT NULL AND NOT EXISTS (SELECT 1 FROM consorcio.detalle_expensa WHERE idDetalleExpensa = @idDetalleExpensa)
    BEGIN
        RAISERROR('Error: La factura (detalle_expensa) ID %d a la que intenta asociar el pago, no existe.', 16, 1, @idDetalleExpensa);
        RETURN -3;
    END

    -- validamos la cuenta de origen
    IF @cuentaOrigen IS NOT NULL AND (@cuentaOrigen = '' OR ISNUMERIC(@cuentaOrigen) = 0)
    BEGIN
        RAISERROR('Error: La cuenta de origen debe ser una cadena numerica no vacia.', 16, 1);
        RETURN -4;
    END

    -- validamos el importe
    IF @importe IS NOT NULL AND @importe <= 0
    BEGIN
        RAISERROR('Error: El importe debe ser un valor mayor a 0.', 16, 1);
        RETURN -5;
    END

    BEGIN TRY
        UPDATE consorcio.pago
        SET
            fecha = ISNULL(@fecha, fecha),
            cuentaOrigen = ISNULL(@cuentaOrigen, cuentaOrigen),
            importe = ISNULL(@importe, importe),
            estaAsociado = ISNULL(@estaAsociado, estaAsociado),
            idDetalleExpensa = ISNULL(@idDetalleExpensa, idDetalleExpensa) 
        WHERE
            idPago = @idPago;

        PRINT 'Pago con ID: ' + CAST(@idPago AS VARCHAR) + ' actualizado con exito.';
        RETURN 0;

    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR('Error inesperado al actualizar el pago: %s', 16, 1, @ErrorMessage);
        RETURN -6;
    END CATCH

    SET NOCOUNT OFF;
END;
GO

---------------
--ELIMINAR PAGO
---------------
CREATE OR ALTER PROCEDURE consorcio.sp_eliminarPago
    @idPago INT
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. Validamos que exista el pago
    IF NOT EXISTS (SELECT 1 FROM consorcio.pago WHERE idPago = @idPago)
    BEGIN
        RAISERROR('Error: El pago ID %d no existe. No se puede eliminar.', 16, 1, @idPago);
        RETURN -1;
    END

    -- validamos si el pago ya fue usado
    IF EXISTS (SELECT 1 FROM consorcio.pago WHERE idPago = @idPago AND idDetalleExpensa IS NOT NULL)
    BEGIN
        RAISERROR('Error: El pago ID %d ya fue utilizado y asociado a una factura. No se puede eliminar.', 16, 1, @idPago);
        RETURN -2;
    END

    BEGIN TRY
        DELETE FROM consorcio.pago
        WHERE idPago = @idPago;

        PRINT 'Pago con ID: ' + CAST(@idPago AS VARCHAR) + ' eliminado con exito.';
        RETURN 0;

    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR('Error inesperado al eliminar el pago: %s', 16, 1, @ErrorMessage);
        RETURN -3;
    END CATCH

    SET NOCOUNT OFF;
END;
GO

--ABM COCHERA

------------------
--INSERTAR COCHERA
------------------
CREATE OR ALTER PROCEDURE consorcio.sp_insertarCochera
    @idUnidadFuncional INT = NULL, --permite null xq puede haber concheras q tdvia no esten asignadas
    @metrosCuadrados INT,
    @coeficiente DECIMAL(5,2),
    @idCocheraCreada INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- validamos q en caso de q la UF no sea null, exista y no este dada de baja
    IF @idUnidadFuncional IS NOT NULL AND 
       NOT EXISTS (SELECT 1 FROM consorcio.unidad_funcional 
                   WHERE idUnidadFuncional = @idUnidadFuncional AND fechaBaja IS NULL)
    BEGIN
        RAISERROR('Error: La Unidad Funcional no existe o esta dada de baja.', 16, 1);
        RETURN -1;
    END

    -- validamos los m2
    IF @metrosCuadrados <= 0
    BEGIN
        RAISERROR('Error: Los metros cuadrados deben ser mayores a 0.', 16, 1);
        RETURN -2;
    END

    -- validamos el coeficiente
    IF @coeficiente <= 0 OR @coeficiente > 100
    BEGIN
        RAISERROR('Error: El coeficiente debe ser un valor entre 0,01 y 100,00.', 16, 1);
        RETURN -3;
    END

    BEGIN TRY
        INSERT INTO consorcio.cochera (
            idUnidadFuncional,
            metrosCuadrados,
            coeficiente
        )
        VALUES (
            @idUnidadFuncional,
            @metrosCuadrados,
            @coeficiente
        );

        SELECT @idCocheraCreada = SCOPE_IDENTITY();--guardamos el id creado para el output
        
        PRINT 'Cochera insertada con exito con ID: ' + CAST(@idCocheraCreada AS VARCHAR);
        RETURN 0;

    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR('Error inesperado al insertar la cochera: %s', 16, 1, @ErrorMessage);
        RETURN -4;
    END CATCH

    SET NOCOUNT OFF;
END;
GO

-------------------
--MODIFICAR COCHERA
-------------------
CREATE OR ALTER PROCEDURE consorcio.sp_modificarCochera
    @idCochera INT, --id a modificar
    @idUnidadFuncional INT = NULL,
    @metrosCuadrados INT = NULL,
    @coeficiente DECIMAL(5,2) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- Validamos q exista la cocherra
    IF NOT EXISTS (SELECT 1 FROM consorcio.cochera WHERE idCochera = @idCochera)
    BEGIN
        RAISERROR('Error: La cochera no existe. No se puede modificar.', 16, 1);
        RETURN -1;
    END

    -- si la UF no es null entonces verificamos q exista y no este dada de baja
    IF @idUnidadFuncional IS NOT NULL AND 
       NOT EXISTS (SELECT 1 FROM consorcio.unidad_funcional 
                   WHERE idUnidadFuncional = @idUnidadFuncional AND fechaBaja IS NULL)
    BEGIN
        RAISERROR('Error: La nueva Unidad Funcional no existe o esta dada de baja.', 16, 1);
        RETURN -2;
    END
    -- Permitimos q se cambie id de UF a NULL para hacer la desasignacion

    -- validamos los m2
    IF @metrosCuadrados IS NOT NULL AND @metrosCuadrados <= 0
    BEGIN
        RAISERROR('Error: Los metros cuadrados deben ser mayores a 0.', 16, 1);
        RETURN -3;
    END

    -- validamo el coef
    IF @coeficiente IS NOT NULL AND (@coeficiente <= 0 OR @coeficiente > 100)
    BEGIN
        RAISERROR('Error: El coeficiente debe ser un valor entre 0,01 y 100,00.', 16, 1);
        RETURN -4;
    END

    BEGIN TRY
        UPDATE consorcio.cochera
        SET
            idUnidadFuncional = ISNULL(@idUnidadFuncional, idUnidadFuncional),
            metrosCuadrados = ISNULL(@metrosCuadrados, metrosCuadrados),
            coeficiente = ISNULL(@coeficiente, coeficiente)
        WHERE
            idCochera = @idCochera;

        PRINT 'Cochera con ID: ' + CAST(@idCochera AS VARCHAR) + ' actualizada con exito.';
        RETURN 0;

    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR('Error inesperado al actualizar la cochera: %s', 16, 1, @ErrorMessage);
        RETURN -5;
    END CATCH

    SET NOCOUNT OFF;
END;
GO

------------------
--ELIMINAR COCHERA
------------------
CREATE OR ALTER PROCEDURE consorcio.sp_eliminarCochera
    @idCochera INT
AS
BEGIN
    SET NOCOUNT ON;

    -- validamos q exista la cochera
    IF NOT EXISTS (SELECT 1 FROM consorcio.cochera WHERE idCochera = @idCochera)
    BEGIN
        RAISERROR('Error: La cochera no existe. No se puede eliminar.', 16, 1);
        RETURN -1;
    END

    -- validamos q la cochera no este asignada a alguna UF, si esta asignada, primero habra que desasignarla y luego se podra eliminar. Se puede desasignar con el modificar, o podriamos hacer otro sp solo para eso
    IF EXISTS (SELECT 1 FROM consorcio.cochera 
               WHERE idCochera = @idCochera 
               AND idUnidadFuncional IS NOT NULL)
    BEGIN
        RAISERROR('Error: La cochera esta asignada a una UF. Primero debe desasignarla.', 16, 1);
        RETURN -2;
    END

    BEGIN TRY
        DELETE FROM consorcio.cochera
        WHERE idCochera = @idCochera;

        PRINT 'Cochera con ID: ' + CAST(@idCochera AS VARCHAR) + ' eliminada con exito.';
        RETURN 0;

    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR('Error inesperado al eliminar la cochera: %s', 16, 1, @ErrorMessage);
        RETURN -3;
    END CATCH

    SET NOCOUNT OFF;
END;
GO

--ABM BAULERA

------------------
--INSERTAR BAULERA
------------------
CREATE OR ALTER PROCEDURE consorcio.sp_insertarBaulera
    @idUnidadFuncional INT = NULL, -- Permite NULL
    @metrosCuadrados INT,
    @coeficiente DECIMAL(5,2),
    @idBauleraCreada INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- validamos q si se provee una UF exista y este activa
    IF @idUnidadFuncional IS NOT NULL AND 
       NOT EXISTS (SELECT 1 FROM consorcio.unidad_funcional 
                   WHERE idUnidadFuncional = @idUnidadFuncional AND fechaBaja IS NULL)
    BEGIN
        RAISERROR('Error: La UF no existe o esta dada de baja.', 16, 1);
        RETURN -1;
    END

    -- validamos los m2
    IF @metrosCuadrados <= 0
    BEGIN
        RAISERROR('Error: Los metros cuadrados deben ser mayores a 0.', 16, 1);
        RETURN -2;
    END

    -- validamos el coef
    IF @coeficiente <= 0 OR @coeficiente > 100
    BEGIN
        RAISERROR('Error: El coeficiente debe ser un valor entre 0,01 y 100,00.', 16, 1);
        RETURN -3;
    END

    BEGIN TRY
        INSERT INTO consorcio.baulera (
            idUnidadFuncional,
            metrosCuadrados,
            coeficiente
        )
        VALUES (
            @idUnidadFuncional,
            @metrosCuadrados,
            @coeficiente
        );

        SELECT @idBauleraCreada = SCOPE_IDENTITY();
        
        PRINT 'Baulera insertada con exito con ID: ' + CAST(@idBauleraCreada AS VARCHAR);
        RETURN 0;

    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR('Error inesperado al insertar la baulera: %s', 16, 1, @ErrorMessage);
        RETURN -4;
    END CATCH

    SET NOCOUNT OFF;
END;
GO

-------------------
--MODIFICAR BAULERA
-------------------
CREATE OR ALTER PROCEDURE consorcio.sp_modificarBaulera
    @idBaulera INT,
    @idUnidadFuncional INT = NULL,
    @metrosCuadrados INT = NULL,
    @coeficiente DECIMAL(5,2) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- validamos q exista la baulera
    IF NOT EXISTS (SELECT 1 FROM consorcio.baulera WHERE idBaulera = @idBaulera)
    BEGIN
        RAISERROR('Error: La baulera no existe. No se puede modificar.', 16, 1);
        RETURN -1;
    END

    -- validamos q si se quiere reasignar sea a una UF q exista y no este dada de baja
    IF @idUnidadFuncional IS NOT NULL AND 
       NOT EXISTS (SELECT 1 FROM consorcio.unidad_funcional 
                   WHERE idUnidadFuncional = @idUnidadFuncional AND fechaBaja IS NULL)
    BEGIN
        RAISERROR('Error: La nueva UF no existe o esta dada de baja.', 16, 1);
        RETURN -2;
    END

    -- validamos m2
    IF @metrosCuadrados IS NOT NULL AND @metrosCuadrados <= 0
    BEGIN
        RAISERROR('Error: Los metros cuadrados deben ser mayores a 0.', 16, 1);
        RETURN -3;
    END

    --validamos coeficiente
    IF @coeficiente IS NOT NULL AND (@coeficiente <= 0 OR @coeficiente > 100)
    BEGIN
        RAISERROR('Error: El coeficiente debe ser un valor entre 0,01 y 100,00.', 16, 1);
        RETURN -4;
    END

    BEGIN TRY
        UPDATE consorcio.baulera
        SET
            idUnidadFuncional = ISNULL(@idUnidadFuncional, idUnidadFuncional),
            metrosCuadrados = ISNULL(@metrosCuadrados, metrosCuadrados),
            coeficiente = ISNULL(@coeficiente, coeficiente)
        WHERE
            idBaulera = @idBaulera;

        PRINT 'Baulera con ID: ' + CAST(@idBaulera AS VARCHAR) + ' actualizada con exito.';
        RETURN 0;

    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR('Error inesperado al actualizar la baulera: %s', 16, 1, @ErrorMessage);
        RETURN -5;
    END CATCH

    SET NOCOUNT OFF;
END;
GO

------------------
--ELIMINAR BAULERA
------------------
CREATE OR ALTER PROCEDURE consorcio.sp_eliminarBaulera
    @idBaulera INT
AS
BEGIN
    SET NOCOUNT ON;

    -- validamos q exista la baulera
    IF NOT EXISTS (SELECT 1 FROM consorcio.baulera WHERE idBaulera = @idBaulera)
    BEGIN
        RAISERROR('Error: La baulera no existe. No se puede eliminar.', 16, 1);
        RETURN -1;
    END

    -- validamos q la baulera no este asignada a ninguna UF
    IF EXISTS (SELECT 1 FROM consorcio.baulera 
               WHERE idBaulera = @idBaulera 
               AND idUnidadFuncional IS NOT NULL)
    BEGIN
        RAISERROR('Error: La baulera esta asignada a una UF. Primero debe desasignarla.', 16, 1);
        RETURN -2;
    END

    BEGIN TRY
        DELETE FROM consorcio.baulera
        WHERE idBaulera = @idBaulera;

        PRINT 'Baulera con ID: ' + CAST(@idBaulera AS VARCHAR) + ' eliminada con exito.';
        RETURN 0;

    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR('Error inesperado al eliminar la baulera: %s', 16, 1, @ErrorMessage);
        RETURN -3;
    END CATCH

    SET NOCOUNT OFF;
END;
GO

--ABM EXPENSA

------------------
--INSERTAR EXPENSA
------------------
CREATE OR ALTER PROCEDURE consorcio.sp_insertarExpensa
    @idConsorcio INT,
    @periodo VARCHAR(12),
    @anio INT,
    @idExpensaCreada INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    -- validamos q exista el consorcio y no este dado de baja
    IF NOT EXISTS (SELECT 1 FROM consorcio.consorcio 
                   WHERE idConsorcio = @idConsorcio AND fechaBaja IS NULL)
    BEGIN
        RAISERROR('Error: El Consorcio no existe o esta dado de baja.', 16, 1);
        RETURN -1;
    END

    -- validamos el periodo
    IF LOWER(@periodo) NOT IN ('enero','febrero','marzo','abril','mayo','junio','julio','agosto','septiembre','octubre','noviembre','diciembre')
    BEGIN
        RAISERROR('Error: El periodo ingresado no es válido.', 16, 1);
        RETURN -2;
    END
    
    -- validamos q no exista una expensa para ese consorcio en el mismo periodo y año
    IF EXISTS (SELECT 1 FROM consorcio.expensa 
               WHERE idConsorcio = @idConsorcio 
               AND periodo = LOWER(@periodo)
               AND anio = @anio)
    BEGIN
        RAISERROR('Error: Ya existe un cierre de expensa para el Consorcio %d en el periodo %s del año %d.', 16, 1, @idConsorcio, @periodo, @anio);
        RETURN -3;
    END

    BEGIN TRY
        INSERT INTO consorcio.expensa (
            idConsorcio,
            periodo,
            anio
        )
        VALUES (
            @idConsorcio,
            LOWER(@periodo),
            @anio
        );

        SELECT @idExpensaCreada = SCOPE_IDENTITY();
        
        PRINT 'Cierre de Expensa insertado con exito con ID: ' + CAST(@idExpensaCreada AS VARCHAR);
        RETURN 0;

    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR('Error inesperado al insertar el cierre de expensa: %s', 16, 1, @ErrorMessage);
        RETURN -4;
    END CATCH

    SET NOCOUNT OFF;
END;
GO

-------------------
--MODIFICAR EXPENSA
-------------------
CREATE OR ALTER PROCEDURE consorcio.sp_modificarExpensa
    @idExpensa INT,
    @idConsorcio INT = NULL,
    @periodo VARCHAR(12) = NULL,
    @anio INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- validamos q la expensa a modif exista
    IF NOT EXISTS (SELECT 1 FROM consorcio.expensa WHERE idExpensa = @idExpensa)
    BEGIN
        RAISERROR('Error: El cierre de expensa ingresado no existe. No se puede modificar.', 16, 1);
        RETURN -1;
    END

    -- Si la expensa ya tiene gastos asociados, o un detalle asociado no permitimos que se modifique
    IF EXISTS (SELECT 1 FROM consorcio.gasto WHERE idExpensa = @idExpensa) OR
       EXISTS (SELECT 1 FROM consorcio.detalle_expensa WHERE idExpensa = @idExpensa)
    BEGIN
        RAISERROR('Error: El cierre de expensa ID %d ya tiene gastos o detalles asociados. No se puede modificar.', 16, 1, @idExpensa);
        RETURN -2;
    END

    -- en caso q se pretenda modificar el consorcio verificamos q exista y no este dado de baja
    IF @idConsorcio IS NOT NULL AND NOT EXISTS (SELECT 1 FROM consorcio.consorcio WHERE idConsorcio = @idConsorcio AND fechaBaja IS NULL)
    BEGIN
        RAISERROR('Error: El nuevo consorcio no existe o esta dado de baja.', 16, 1);
        RETURN -3;
    END
    
    -- validamos periodo si se quiere cambiar
    IF @periodo IS NOT NULL AND LOWER(@periodo) NOT IN ('enero','febrero','marzo','abril','mayo','junio','julio','agosto','septiembre','octubre','noviembre','diciembre')
    BEGIN
        RAISERROR('Error: El nuevo periodo ''%s'' no es valido.', 16, 1, @periodo);
        RETURN -4;
    END

    -- validamos q la nueva combinacion de expensa para un cierto consorcio en un cierto periodo y año
    IF @idConsorcio IS NOT NULL OR @periodo IS NOT NULL OR @anio IS NOT NULL
    BEGIN
        DECLARE @targetConsorcio INT, @targetPeriodo VARCHAR(12), @targetAnio INT;
        
        -- obtenemos los valores actuales
        SELECT @targetConsorcio = idConsorcio, @targetPeriodo = periodo, @targetAnio = anio
        FROM consorcio.expensa WHERE idExpensa = @idExpensa;
        
        -- obtenemos la combinacion final
        SET @targetConsorcio = ISNULL(@idConsorcio, @targetConsorcio);
        SET @targetPeriodo = ISNULL(LOWER(@periodo), @targetPeriodo);
        SET @targetAnio = ISNULL(@anio, @targetAnio);
        
        -- validamos q dicha combinacion sea unica
        IF EXISTS (SELECT 1 FROM consorcio.expensa
                   WHERE idConsorcio = @targetConsorcio
                   AND periodo = @targetPeriodo
                   AND anio = @targetAnio
                   AND idExpensa <> @idExpensa)
        BEGIN
            RAISERROR('Error: La nueva combinacion (Consorcio %d, %s %d) ya existe en otra expensa.', 16, 1, @targetConsorcio, @targetPeriodo, @targetAnio);
            RETURN -5;
        END
    END

    BEGIN TRY
        UPDATE consorcio.expensa
        SET
            idConsorcio = ISNULL(@idConsorcio, idConsorcio),
            periodo = ISNULL(LOWER(@periodo), periodo),
            anio = ISNULL(@anio, anio)
        WHERE
            idExpensa = @idExpensa;

        PRINT 'Cierre de Expensa ID: ' + CAST(@idExpensa AS VARCHAR) + ' actualizado con exito.';
        RETURN 0;

    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR('Error inesperado al actualizar el cierre de expensa: %s', 16, 1, @ErrorMessage);
        RETURN -6;
    END CATCH

    SET NOCOUNT OFF;
END;
GO

------------------
--ELIMINAR EXPENSA
------------------
CREATE OR ALTER PROCEDURE consorcio.sp_eliminarExpensa
    @idExpensa INT
AS
BEGIN
    SET NOCOUNT ON;

    -- validamos q la expensa exista
    IF NOT EXISTS (SELECT 1 FROM consorcio.expensa WHERE idExpensa = @idExpensa)
    BEGIN
        RAISERROR('Error: La expensa ingresada no existe. No se puede eliminar.', 16, 1);
        RETURN -1;
    END

    -- validamos q la expensa no tenga datos asociados
    IF EXISTS (SELECT 1 FROM consorcio.gasto WHERE idExpensa = @idExpensa) OR
       EXISTS (SELECT 1 FROM consorcio.detalle_expensa WHERE idExpensa = @idExpensa)
    BEGIN
        RAISERROR('Error: La expensa ya tiene gastos o detalles asociados. No se puede eliminar.', 16, 1);
        RETURN -2;
    END

    BEGIN TRY
        DELETE FROM consorcio.expensa
        WHERE idExpensa = @idExpensa;

        PRINT 'Expensa con ID: ' + CAST(@idExpensa AS VARCHAR) + ' eliminada con exito.';
        RETURN 0;

    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR('Error inesperado al eliminar la expensa: %s', 16, 1, @ErrorMessage);
        RETURN -3;
    END CATCH

    SET NOCOUNT OFF;
END;
GO

--ABM DETALLE EXPENSA

--------------------------
--INSERTAR DETALLE EXPENSA
--------------------------
CREATE OR ALTER PROCEDURE consorcio.sp_insertarDetalleExpensa
    @idExpensa INT,
    @idUnidadFuncional INT,
    @fechaPrimerVenc DATE,
    @saldoAnterior DECIMAL (12,2),
    @pagoRecibido DECIMAL (12,2),
    @deuda DECIMAL (12,2),
    @interesPorMora DECIMAL (12, 2),
    @expensasOrdinarias DECIMAL (12, 2),
    @expensasExtraordinarias DECIMAL (12, 2),
    @totalAPagar DECIMAL (12, 2),
    @fechaEmision DATE = NULL,
    @fechaSegundoVenc DATE = NULL,
    @idDetalleExpensaCreado INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- validamos q exista la expensa
    IF NOT EXISTS (SELECT 1 FROM consorcio.expensa WHERE idExpensa = @idExpensa)
    BEGIN
        RAISERROR('Error: La expensa %d no existe.', 16, 1, @idExpensa);
        RETURN -1;
    END

    -- validamos q la uf exista y este activa
    IF NOT EXISTS (SELECT 1 FROM consorcio.unidad_funcional 
                   WHERE idUnidadFuncional = @idUnidadFuncional AND fechaBaja IS NULL)
    BEGIN
        RAISERROR('Error: La UF %d no existe o esta dada de baja.', 16, 1, @idUnidadFuncional);
        RETURN -2;
    END
    
    -- validamos q no exita un detalle para la expensa y uf que se pretende insertar
    IF EXISTS (SELECT 1 FROM consorcio.detalle_expensa
               WHERE idExpensa = @idExpensa 
               AND idUnidadFuncional = @idUnidadFuncional)
    BEGIN
        RAISERROR('Error: Ya existe una factura para la UF %d en la expensa %d. No se puede duplicar.', 16, 1, @idUnidadFuncional, @idExpensa);
        RETURN -3;
    END

    -- validamos q la uf pertenezca al consorcio de la expensa
    DECLARE @CierreConsorcio INT, @UFConsorcio INT;
    
    SELECT @CierreConsorcio = idConsorcio FROM consorcio.expensa WHERE idExpensa = @idExpensa;
    SELECT @UFConsorcio = idConsorcio FROM consorcio.unidad_funcional WHERE idUnidadFuncional = @idUnidadFuncional;

    IF @CierreConsorcio <> @UFConsorcio
    BEGIN
        RAISERROR('Error: La UF %d NO pertenece al Consorcio %d. La asignación es incoherente.', 16, 1, @idUnidadFuncional, @CierreConsorcio);
        RETURN -4;
    END

    -- validamos fechas
    DECLARE @emision DATE = ISNULL(@fechaEmision, GETDATE());
    IF @emision >= @fechaPrimerVenc
    BEGIN
        RAISERROR('Error: La fecha de primer vencimiento debe ser posterior a la fecha de emision.', 16, 1);
        RETURN -5;
    END
    
    IF @fechaSegundoVenc IS NOT NULL AND @fechaSegundoVenc <= @fechaPrimerVenc
    BEGIN
        RAISERROR('Error: La fecha de segundo vencimiento debe ser posterior a la del primero.', 16, 1);
        RETURN -6;
    END
    
    -- validamos montos
    IF @pagoRecibido < 0 OR @interesPorMora < 0 OR @expensasOrdinarias < 0 OR @expensasExtraordinarias < 0 OR @totalAPagar < 0
    BEGIN
        RAISERROR('Error: Los montos monetarios (pagos, intereses, expensas, total) no pueden ser negativos.', 16, 1);
        RETURN -7;
    END

    BEGIN TRY
        INSERT INTO consorcio.detalle_expensa (
            idExpensa, idUnidadFuncional, fechaEmision, fechaPrimerVenc, fechaSegundoVenc,
            saldoAnterior, pagoRecibido, deuda, interesPorMora,
            expensasOrdinarias, expensasExtraordinarias, totalAPagar
        )
        VALUES (
            @idExpensa, @idUnidadFuncional, @emision, @fechaPrimerVenc, @fechaSegundoVenc,
            @saldoAnterior, @pagoRecibido, @deuda, @interesPorMora,
            @expensasOrdinarias, @expensasExtraordinarias, @totalAPagar
        );

        SELECT @idDetalleExpensaCreado = SCOPE_IDENTITY();
        
        PRINT 'Detalle de Expensa insertado con exito con ID: ' + CAST(@idDetalleExpensaCreado AS VARCHAR);
        RETURN 0;

    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR('Error inesperado al insertar el detalle de expensa: %s', 16, 1, @ErrorMessage);
        RETURN -8;
    END CATCH

    SET NOCOUNT OFF;
END;
GO

---------------------------
--MODIFICAR DETALLE EXPENSA
---------------------------
CREATE OR ALTER PROCEDURE consorcio.sp_modificarDetalleExpensa
  	@idDetalleExpensa INT,
  	@fechaPrimerVenc DATE = NULL,
  	@fechaSegundoVenc DATE = NULL,
  	@saldoAnterior DECIMAL (12,2) = NULL,
  	@pagoRecibido DECIMAL (12,2) = NULL,
  	@deuda DECIMAL (12,2) = NULL,
  	@interesPorMora DECIMAL (12, 2) = NULL,
  	@expensasOrdinarias DECIMAL (12, 2) = NULL,
  	@expensasExtraordinarias DECIMAL (12, 2) = NULL,
  	@totalAPagar DECIMAL (12, 2) = NULL,
  	@fechaEmision DATE = NULL
AS
BEGIN
  	SET NOCOUNT ON;

  	-- validamos q exista el detalle y nos guardamos datos q nos interesan para validar
  	DECLARE @currentFechaEmision DATE;
  	DECLARE @currentFechaPrimerVenc DATE;
    
  	SELECT 
      	@currentFechaEmision = fechaEmision,
      	@currentFechaPrimerVenc = fechaPrimerVenc
  	FROM consorcio.detalle_expensa 
  	WHERE idDetalleExpensa = @idDetalleExpensa;

  	IF @currentFechaEmision IS NULL 
  	BEGIN
      	RAISERROR('Error: El detalle de expensa con ID %d no existe.', 16, 1, @idDetalleExpensa);
      	RETURN -1;
  	END

  	IF @fechaEmision IS NOT NULL
  	BEGIN
      	RAISERROR('Error: No se permite modificar la fecha de emision de una factura existente.', 16, 1);
      	RETURN -5;
  	END

  	-- validamos fechas de vencimiento
  	IF @fechaPrimerVenc IS NOT NULL AND @fechaPrimerVenc <= @currentFechaEmision
  	BEGIN
        DECLARE @fechaEmisionStr VARCHAR(10) = CONVERT(VARCHAR, @currentFechaEmision, 103);
      	RAISERROR('Error: La nueva fecha de primer vencimiento debe ser posterior a la fecha de emision (%s).', 16, 1, @fechaEmisionStr);
      	RETURN -6;
  	END

  	-- Determinamos el valor final del primer vencimiento para la siguiente validacion
  	DECLARE @finalPrimerVenc DATE = ISNULL(@fechaPrimerVenc, @currentFechaPrimerVenc);

  	IF @fechaSegundoVenc IS NOT NULL AND @fechaSegundoVenc <= @finalPrimerVenc
  	BEGIN
        DECLARE @finalPrimerVencStr VARCHAR(10) = CONVERT(VARCHAR, @finalPrimerVenc, 103);
      	RAISERROR('Error: La nueva fecha de segundo vencimiento debe ser posterior a la del primero (%s).', 16, 1, @finalPrimerVencStr);
      	RETURN -7;
  	END

  	-- validamos montos
  	IF (@pagoRecibido IS NOT NULL AND @pagoRecibido < 0) OR
      	(@interesPorMora IS NOT NULL AND @interesPorMora < 0) OR
      	(@expensasOrdinarias IS NOT NULL AND @expensasOrdinarias < 0) OR
      	(@expensasExtraordinarias IS NOT NULL AND @expensasExtraordinarias < 0) OR
      	(@totalAPagar IS NOT NULL AND @totalAPagar < 0)
  	BEGIN
      	RAISERROR('Error: Los montos monetarios (pago recibido, mora, expensas, total) no pueden ser negativos.', 16, 1);
      	RETURN -8;
  	END

  	BEGIN TRY
        
      	UPDATE consorcio.detalle_expensa
      	SET
          	fechaPrimerVenc = ISNULL(@fechaPrimerVenc, fechaPrimerVenc),
          	fechaSegundoVenc = ISNULL(@fechaSegundoVenc, fechaSegundoVenc),
          	saldoAnterior = ISNULL(@saldoAnterior, saldoAnterior),
          	pagoRecibido = ISNULL(@pagoRecibido, pagoRecibido),
          	deuda = ISNULL(@deuda, deuda),
          	interesPorMora = ISNULL(@interesPorMora, interesPorMora),
          	expensasOrdinarias = ISNULL(@expensasOrdinarias, expensasOrdinarias),
          	expensasExtraordinarias = ISNULL(@expensasExtraordinarias, expensasExtraordinarias),
          	totalAPagar = ISNULL(@totalAPagar, totalAPagar)
      	WHERE
          	idDetalleExpensa = @idDetalleExpensa;

      	PRINT 'Detalle de Expensa ID ' + CAST(@idDetalleExpensa AS VARCHAR) + ' actualizado con exito.';
      	RETURN 0;

  	END TRY
  	BEGIN CATCH
      	DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
      	RAISERROR('Error inesperado al actualizar el detalle: %s', 16, 1, @ErrorMessage);
      	RETURN -9;
  	END CATCH

  	SET NOCOUNT OFF;
END;
GO

--------------------------
--ELIMINAR DETALLE EXPENSA
--------------------------
CREATE OR ALTER PROCEDURE consorcio.sp_eliminarDetalleExpensa
    @idDetalleExpensa INT
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. valido q el detalle exista
    IF NOT EXISTS (SELECT 1 FROM consorcio.detalle_expensa WHERE idDetalleExpensa = @idDetalleExpensa)
    BEGIN
        RAISERROR('Error: El detalle de expensa ID %d no existe. No se puede eliminar.', 16, 1, @idDetalleExpensa);
        RETURN -1;
    END

    -- validamos si tiene algun pago asociado
    IF EXISTS (SELECT 1 FROM consorcio.pago WHERE idDetalleExpensa = @idDetalleExpensa)
    BEGIN
        RAISERROR('Error: La factura ID %d ya tiene uno o mas pagos asociados. No se puede eliminar.', 16, 1, @idDetalleExpensa);
        RETURN -2;
    END

    BEGIN TRY
        DELETE FROM consorcio.detalle_expensa
        WHERE idDetalleExpensa = @idDetalleExpensa;

        PRINT 'Detalle de Expensa con ID: ' + CAST(@idDetalleExpensa AS VARCHAR) + ' eliminado con exito.';
        RETURN 0;

    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR('Error inesperado al eliminar el detalle de expensa: %s', 16, 1, @ErrorMessage);
        RETURN -3;
    END CATCH

  	SET NOCOUNT OFF;
END;
GO

--ABM GASTO

----------------
--INSERTAR GASTO
----------------
CREATE OR ALTER PROCEDURE consorcio.sp_insertarGasto
    @idExpensa INT,
    @subTotalOrdinarios DECIMAL(12,2),
    @subTotalExtraOrd DECIMAL(12,2),
    @idGastoCreado INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- validamos q exista la expensa
    IF NOT EXISTS (SELECT 1 FROM consorcio.expensa WHERE idExpensa = @idExpensa)
    BEGIN
        RAISERROR('Error: La expensa %d no existe.', 16, 1, @idExpensa);
        RETURN -1;
    END

    -- Si se le genero un detalle a la expensa ya no se puede cargar mas gastos al cierre
    IF EXISTS (SELECT 1 FROM consorcio.detalle_expensa WHERE idExpensa = @idExpensa)
    BEGIN
        RAISERROR('Error: No se pueden cargar mas gastos a la expensa de ID %d. Ya se genero al menos un detalle_expensa.', 16, 1, @idExpensa);
        RETURN -2;
    END
    
    -- validamos los montos
    IF @subTotalOrdinarios < 0 OR @subTotalExtraOrd < 0
    BEGIN
        RAISERROR('Error: Los subtotales de gastos no pueden ser negativos.', 16, 1);
        RETURN -3;
    END

    BEGIN TRY
        INSERT INTO consorcio.gasto (
            idExpensa,
            subTotalOrdinarios,
            subTotalExtraOrd
        )
        VALUES (
            @idExpensa,
            @subTotalOrdinarios,
            @subTotalExtraOrd
        );

        SELECT @idGastoCreado = SCOPE_IDENTITY();
        
        PRINT 'Gasto insertado con exito con ID: ' + CAST(@idGastoCreado AS VARCHAR) + ' para el Cierre ID ' + CAST(@idExpensa AS VARCHAR) + '.';
        RETURN 0;

    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR('Error inesperado al insertar el gasto: %s', 16, 1, @ErrorMessage);
        RETURN -4;
    END CATCH

    SET NOCOUNT OFF;
END;
GO

-----------------
--MODIFICAR GASTO
-----------------
CREATE OR ALTER PROCEDURE consorcio.sp_modificarGasto
    @idGasto INT,
    @subTotalOrdinarios DECIMAL(12,2) = NULL,
    @subTotalExtraOrd DECIMAL(12,2) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- valido q exista el gasto
    DECLARE @currentIdExpensa INT;
    
    SELECT @currentIdExpensa = idExpensa 
    FROM consorcio.gasto 
    WHERE idGasto = @idGasto;

    IF @currentIdExpensa IS NULL
    BEGIN
        RAISERROR('Error: El Gasto con ID %d no existe. No se puede modificar.', 16, 1, @idGasto);
        RETURN -1;
    END
    
    -- validamos q la expensa no tenga un detalle generado aun
    IF EXISTS (SELECT 1 FROM consorcio.detalle_expensa WHERE idExpensa = @currentIdExpensa)
    BEGIN
        RAISERROR('Error: No se puede modificar el gasto de ID %d. Ya se genero al menos un detalle para la expensa ID %d.', 16, 1, @idGasto, @currentIdExpensa);
        RETURN -2;
    END

    -- validamos montos
    IF (@subTotalOrdinarios IS NOT NULL AND @subTotalOrdinarios < 0) OR 
       (@subTotalExtraOrd IS NOT NULL AND @subTotalExtraOrd < 0)
    BEGIN
        RAISERROR('Error: Los subtotales de gastos no pueden ser negativos.', 16, 1);
        RETURN -3;
    END

    BEGIN TRY
        UPDATE consorcio.gasto
        SET
            subTotalOrdinarios = ISNULL(@subTotalOrdinarios, subTotalOrdinarios),
            subTotalExtraOrd = ISNULL(@subTotalExtraOrd, subTotalExtraOrd)
        WHERE
            idGasto = @idGasto;

        PRINT 'Gasto con ID: ' + CAST(@idGasto AS VARCHAR) + ' actualizado con exito.';
        RETURN 0;

    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR('Error inesperado al actualizar el gasto: %s', 16, 1, @ErrorMessage);
        RETURN -4;
    END CATCH

    SET NOCOUNT OFF;
END;
GO

----------------
--ELIMINAR GASTO
----------------
CREATE OR ALTER PROCEDURE consorcio.sp_eliminarGasto
    @idGasto INT
AS
BEGIN
    SET NOCOUNT ON;

    -- validamos q exista el gasto y obtenemos a q expensa pertenece
    DECLARE @currentIdExpensa INT;
    
    SELECT @currentIdExpensa = idExpensa 
    FROM consorcio.gasto 
    WHERE idGasto = @idGasto;

    IF @currentIdExpensa IS NULL
    BEGIN
        RAISERROR('Error: El Gasto con ID %d no existe. No se puede eliminar.', 16, 1, @idGasto);
        RETURN -1;
    END

    -- validamos q la expensa a la q pertenece el gasto aun no tenga un detalle
    IF EXISTS (SELECT 1 FROM consorcio.detalle_expensa WHERE idExpensa = @currentIdExpensa)
    BEGIN
        RAISERROR('Error: No se puede eliminar el gasto de ID %d. Ya se genero al menos un detalle para la expensa de ID %d.', 16, 1, @idGasto, @currentIdExpensa);
        RETURN -2;
    END

    -- si el gasto ya tiene gastos ordinarios o extraordinarios asociados no se puede eliminar
    IF EXISTS (SELECT 1 FROM consorcio.gasto_ordinario WHERE idGasto = @idGasto) OR
       EXISTS (SELECT 1 FROM consorcio.gasto_extra_ordinario WHERE idGasto = @idGasto)
    BEGIN
        RAISERROR('Error: No se puede eliminar el gasto de ID %d. Tiene gastos ordinarios/extraordinarios asociados. Elimine esos detalles primero.', 16, 1, @idGasto);
        RETURN -3;
    END

    BEGIN TRY
        DELETE FROM consorcio.gasto
        WHERE idGasto = @idGasto;

        PRINT 'Gasto con ID: ' + CAST(@idGasto AS VARCHAR) + ' eliminado con exito.';
        RETURN 0;

    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR('Error inesperado al eliminar el gasto: %s', 16, 1, @ErrorMessage);
        RETURN -4;
    END CATCH

    SET NOCOUNT OFF;
END;
GO

--ABM GASTO ORDINARIO

--------------------------
--INSERTAR GASTO ORDINARIO
--------------------------
CREATE OR ALTER PROCEDURE consorcio.sp_insertarGastoOrdinario
    @idGasto INT,
    @tipoGasto VARCHAR(20),
    @subTipoGasto VARCHAR(30),
    @nomEmpresa VARCHAR(40),
    @nroFactura INT,
    @importe DECIMAL(12,2),
    @idGastoOrdCreado INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- validamos q el gasto "padre" exista
    DECLARE @idExpensaPadre INT;
    SELECT @idExpensaPadre = idExpensa FROM consorcio.gasto WHERE idGasto = @idGasto;
    
    IF @idExpensaPadre IS NULL
    BEGIN
        RAISERROR('Error: El gasto padre de ID %d no existe.', 16, 1, @idGasto);
        RETURN -1;
    END

    -- si la expensa tiene detalle ya no se pueden cargar mas gastos
    IF EXISTS (SELECT 1 FROM consorcio.detalle_expensa WHERE idExpensa = @idExpensaPadre)
    BEGIN
        RAISERROR('Error: No se pueden cargar mas gastos a la expensa. Ya se emitierio su detalle.', 16, 1);
        RETURN -2;
    END

    -- validamos los importes
    IF @importe IS NULL OR @importe <= 0
    BEGIN
        RAISERROR('Error: El importe debe ser un valor mayor a 0.', 16, 1);
        RETURN -3;
    END

    -- validamos q no exista otro gasto con el mismo numero de factura de la misma empresa
    IF EXISTS (SELECT 1 FROM consorcio.gasto_ordinario WHERE nroFactura = @nroFactura AND nomEmpresa = @nomEmpresa)
    BEGIN
        RAISERROR('Error: Ya existe un gasto ordinario con el Nro. de Factura %d para la empresa %s.', 16, 1, @nroFactura, @nomEmpresa);
        RETURN -4;
    END
    
    -- validamos el tipo de gasto
    IF LOWER(@tipoGasto) NOT IN ('bancario','limpieza','administracion','seguros','generales','servicios publicos')
    BEGIN
        RAISERROR('Error: El tipo de gasto no es valido. Consulte la lista de tipos permitidos.', 16, 1);
        RETURN -5;
    END

    BEGIN TRY
        INSERT INTO consorcio.gasto_ordinario (
            idGasto, tipoGasto, subTipoGasto, nomEmpresa, nroFactura, importe
        )
        VALUES (
            @idGasto, LOWER(@tipoGasto), @subTipoGasto, @nomEmpresa, @nroFactura, @importe
        );

        SELECT @idGastoOrdCreado = SCOPE_IDENTITY();
        
        PRINT 'Gasto Ordinario insertado con ID: ' + CAST(@idGastoOrdCreado AS VARCHAR);
        RETURN 0;

    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR('Error inesperado al insertar el gasto ordinario: %s', 16, 1, @ErrorMessage);
        RETURN -6;
    END CATCH

    SET NOCOUNT OFF;
END;
GO

---------------------------
--MODIFICAR GASTO ORDINARIO
---------------------------
CREATE OR ALTER PROCEDURE consorcio.sp_modificarGastoOrdinario
    @idGastoOrd INT,
    @idGasto INT = NULL,
    @tipoGasto VARCHAR(20) = NULL,
    @subTipoGasto VARCHAR(30) = NULL,
    @nomEmpresa VARCHAR(40) = NULL,
    @nroFactura INT = NULL,
    @importe DECIMAL(12,2) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- validamos q exista dicho gasto y capturamos su padre
    DECLARE @currentIdGasto INT;
    SELECT @currentIdGasto = idGasto FROM consorcio.gasto_ordinario WHERE idGastoOrd = @idGastoOrd;
    
    IF @currentIdGasto IS NULL
    BEGIN
        RAISERROR('Error: El Gasto Ordinario de ID %d no existe. No se puede modificar.', 16, 1, @idGastoOrd);
        RETURN -1;
    END
    
    -- si la expensa a la q corresponde el gasto ya tiene un detalle, no se puede modificar
    DECLARE @finalIdGasto INT = ISNULL(@idGasto, @currentIdGasto);
    DECLARE @idExpensaPadre INT;
    
    SELECT @idExpensaPadre = idExpensa FROM consorcio.gasto WHERE idGasto = @finalIdGasto;

    IF EXISTS (SELECT 1 FROM consorcio.detalle_expensa WHERE idExpensa = @idExpensaPadre)
    BEGIN
        RAISERROR('Error: No se puede modificar el Gasto Ordinario de ID %d. Ya se emitio un detalle para la expensa.', 16, 1, @idGastoOrd);
        RETURN -2;
    END

    -- validamos importe
    IF @importe IS NOT NULL AND @importe <= 0
    BEGIN
        RAISERROR('Error: El importe debe ser un valor mayor a 0.', 16, 1);
        RETURN -3;
    END

    -- validamos el tipo de gasto
    IF @tipoGasto IS NOT NULL AND LOWER(@tipoGasto) NOT IN ('mantenimiento','limpieza','administracion','seguros','generales','servicios publicos')
    BEGIN
        RAISERROR('Error: El tipo de gasto no es valido.', 16, 1);
        RETURN -4;
    END
    
    -- validamos q no exista el mismo numero de factura para la misma empresa
    IF @nroFactura IS NOT NULL OR @nomEmpresa IS NOT NULL
    BEGIN
        -- obtenemos los datos actuales
        DECLARE @currentNroFactura INT, @currentNomEmpresa VARCHAR(40);
        SELECT @currentNroFactura = nroFactura, @currentNomEmpresa = nomEmpresa FROM consorcio.gasto_ordinario WHERE idGastoOrd = @idGastoOrd;
        
        DECLARE @targetNroFactura INT = ISNULL(@nroFactura, @currentNroFactura);
        DECLARE @targetNomEmpresa VARCHAR(40) = ISNULL(@nomEmpresa, @currentNomEmpresa);

        IF EXISTS (SELECT 1 FROM consorcio.gasto_ordinario 
                   WHERE nroFactura = @targetNroFactura 
                   AND nomEmpresa = @targetNomEmpresa
                   AND idGastoOrd <> @idGastoOrd)
        BEGIN
            RAISERROR('Error: La combinacion Nro. Factura (%d) y Empresa (%s) ya existe en otro gasto ordinario.', 16, 1, @targetNroFactura, @targetNomEmpresa);
            RETURN -5;
        END
    END
    
    BEGIN TRY
        UPDATE consorcio.gasto_ordinario
        SET
            idGasto = ISNULL(@idGasto, idGasto),
            tipoGasto = ISNULL(LOWER(@tipoGasto), tipoGasto),
            subTipoGasto = ISNULL(@subTipoGasto, subTipoGasto),
            nomEmpresa = ISNULL(@nomEmpresa, nomEmpresa),
            nroFactura = ISNULL(@nroFactura, nroFactura),
            importe = ISNULL(@importe, importe)
        WHERE
            idGastoOrd = @idGastoOrd;

        PRINT 'Gasto Ordinario ID: ' + CAST(@idGastoOrd AS VARCHAR) + ' actualizado con exito.';
        RETURN 0;

    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR('Error inesperado al actualizar el gasto ordinario: %s', 16, 1, @ErrorMessage);
        RETURN -6;
    END CATCH

    SET NOCOUNT OFF;
END;
GO

--------------------------
--ELIMINAR GASTO ORDINARIO
--------------------------
CREATE OR ALTER PROCEDURE consorcio.sp_eliminarGastoOrdinario
    @idGastoOrd INT
AS
BEGIN
    SET NOCOUNT ON;

    -- validamos q dicho gasto exista y capturamos su padre
    DECLARE @currentIdGasto INT;
    SELECT @currentIdGasto = idGasto FROM consorcio.gasto_ordinario WHERE idGastoOrd = @idGastoOrd;
    
    IF @currentIdGasto IS NULL
    BEGIN
        RAISERROR('Error: El Gasto Ordinario de ID %d no existe. No se puede eliminar.', 16, 1, @idGastoOrd);
        RETURN -1;
    END

    -- si la expensa a la q pertenece ya tiene un detalle no permite q se elimine el gasto
    DECLARE @idExpensaPadre INT;
    SELECT @idExpensaPadre = idExpensa FROM consorcio.gasto WHERE idGasto = @currentIdGasto;

    IF EXISTS (SELECT 1 FROM consorcio.detalle_expensa WHERE idExpensa = @idExpensaPadre)
    BEGIN
        RAISERROR('Error: No se puede eliminar el Gasto Ordinario de ID %d. Ya se emitio un detalle para la expensa de ID %d.', 16, 1, @idGastoOrd, @idExpensaPadre);
        RETURN -2;
    END
    
    BEGIN TRY
        DELETE FROM consorcio.gasto_ordinario
        WHERE idGastoOrd = @idGastoOrd;

        PRINT 'Gasto Ordinario con ID: ' + CAST(@idGastoOrd AS VARCHAR) + ' eliminado con exito.';
        RETURN 0;

    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR('Error inesperado al eliminar el gasto ordinario: %s', 16, 1, @ErrorMessage);
        RETURN -3;
    END CATCH

    SET NOCOUNT OFF;
END;
GO

--ABM GASTO EXTRA ORDINARIO

--------------------------------
--INSERTAR GASTO EXTRA ORDINARIO
--------------------------------
CREATE OR ALTER PROCEDURE consorcio.sp_insertarGastoExtraOrdinario
    @idGasto INT,
    @tipoGasto VARCHAR(12),
    @nomEmpresa VARCHAR(40),
    @nroFactura INT,
    @descripcion VARCHAR(50),
    @nroCuota INT,
    @totalCuotas INT,
    @importe DECIMAL(12,2),
    @idGastoExtraOrdCreado INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- validamos q el gasto padre exista
    DECLARE @idExpensaPadre INT;
    SELECT @idExpensaPadre = idExpensa FROM consorcio.gasto WHERE idGasto = @idGasto;
    
    IF @idExpensaPadre IS NULL
    BEGIN
        RAISERROR('Error: El gasto padre ID %d no existe.', 16, 1, @idGasto);
        RETURN -1;
    END

    -- validamos q la expensa no tenga un detalle aun
    IF EXISTS (SELECT 1 FROM consorcio.detalle_expensa WHERE idExpensa = @idExpensaPadre)
    BEGIN
        RAISERROR('Error: No se pueden cargar mas gastos extraordinarios. Ya se emitio un detalle de la expensa.', 16, 1);
        RETURN -2;
    END

    -- validamos el importe
    IF @importe IS NULL OR @importe <= 0
    BEGIN
        RAISERROR('Error: El importe debe ser un valor mayor a 0.', 16, 1);
        RETURN -3;
    END

    -- validamos el tipo de gasto
    IF LOWER(@tipoGasto) NOT IN ('reparacion','construccion')
    BEGIN
        RAISERROR('Error: El tipo de gasto extraordinario no es valido (Debe ser "reparacion" o "construccion").', 16, 1);
        RETURN -4;
    END

    -- validamos las cuotas
    IF @nroCuota IS NULL OR @totalCuotas IS NULL OR @nroCuota <= 0 OR @totalCuotas <= 0 OR @nroCuota > @totalCuotas
    BEGIN
        RAISERROR('Error: Las cuotas son invalidas. nroCuota y totalCuotas deben ser > 0, y nroCuota no puede exceder totalCuotas.', 16, 1);
        RETURN -5;
    END
    
    -- validamos q no exista otro gasto con el mismo numero de factura para la misma empresa
    IF EXISTS (SELECT 1 FROM consorcio.gasto_extra_ordinario WHERE nroFactura = @nroFactura AND nomEmpresa = @nomEmpresa)
    BEGIN
        RAISERROR('Error: Ya existe un gasto extraordinario con el Nro. de Factura %d para la empresa %s.', 16, 1, @nroFactura, @nomEmpresa);
        RETURN -6;
    END

    BEGIN TRY
        INSERT INTO consorcio.gasto_extra_ordinario (
            idGasto, tipoGasto, nomEmpresa, nroFactura, descripcion, nroCuota, totalCuotas, importe
        )
        VALUES (
            @idGasto, LOWER(@tipoGasto), @nomEmpresa, @nroFactura, @descripcion, @nroCuota, @totalCuotas, @importe
        );

        SELECT @idGastoExtraOrdCreado = SCOPE_IDENTITY();
        
        PRINT 'Gasto Extraordinario insertado con ID: ' + CAST(@idGastoExtraOrdCreado AS VARCHAR);
        RETURN 0;

    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR('Error inesperado al insertar el gasto extraordinario: %s', 16, 1, @ErrorMessage);
        RETURN -7;
    END CATCH

    SET NOCOUNT OFF;
END;
GO

---------------------------------
--MODIFICAR GASTO EXTRA ORDINARIO
---------------------------------
CREATE OR ALTER PROCEDURE consorcio.sp_modificarGastoExtraOrdinario
    @idGastoExtraOrd INT,
    @idGasto INT = NULL,
    @tipoGasto VARCHAR(12) = NULL,
    @nomEmpresa VARCHAR(40) = NULL,
    @nroFactura INT = NULL,
    @descripcion VARCHAR(50) = NULL,
    @nroCuota INT = NULL,
    @totalCuotas INT = NULL,
    @importe DECIMAL(12,2) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- validamos q exista el gasto y capoturamos su padre
    DECLARE @currentIdGasto INT;
    SELECT @currentIdGasto = idGasto FROM consorcio.gasto_extra_ordinario WHERE idGastoExtraOrd = @idGastoExtraOrd;
    
    IF @currentIdGasto IS NULL
    BEGIN
        RAISERROR('Error: El Gasto Extraordinario de ID %d no existe. No se puede modificar.', 16, 1, @idGastoExtraOrd);
        RETURN -1;
    END
    
    -- si la expensa tiene detalle no se permite q se modifique el gasto
    DECLARE @idExpensaPadre INT;
    DECLARE @finalIdGasto INT = ISNULL(@idGasto, @currentIdGasto);
    
    SELECT @idExpensaPadre = idExpensa FROM consorcio.gasto WHERE idGasto = @finalIdGasto;

    IF EXISTS (SELECT 1 FROM consorcio.detalle_expensa WHERE idExpensa = @idExpensaPadre)
    BEGIN
        RAISERROR('Error: No se puede modificar el Gasto Extraordinario de ID %d. Ya se emitio un detalle para la expensa.', 16, 1, @idGastoExtraOrd);
        RETURN -2;
    END

    -- validamos importe
    IF @importe IS NOT NULL AND @importe <= 0
    BEGIN
        RAISERROR('Error: El importe debe ser un valor mayor a 0.', 16, 1);
        RETURN -3;
    END

    -- validamos tipo de gasto
    IF @tipoGasto IS NOT NULL AND LOWER(@tipoGasto) NOT IN ('reparacion','construccion')
    BEGIN
        RAISERROR('Error: El tipo de gasto extraordinario no es válido.', 16, 1);
        RETURN -4;
    END

    -- validamos las cuotas
    IF @nroCuota IS NOT NULL OR @totalCuotas IS NOT NULL
    BEGIN
        -- Capturar valores actuales
        DECLARE @currentNroCuota INT, @currentTotalCuotas INT;
        SELECT @currentNroCuota = nroCuota, @currentTotalCuotas = totalCuotas FROM consorcio.gasto_extra_ordinario WHERE idGastoExtraOrd = @idGastoExtraOrd;
        
        DECLARE @targetNroCuota INT = ISNULL(@nroCuota, @currentNroCuota);
        DECLARE @targetTotalCuotas INT = ISNULL(@totalCuotas, @currentTotalCuotas);

        IF @targetNroCuota <= 0 OR @targetTotalCuotas <= 0 OR @targetNroCuota > @targetTotalCuotas
        BEGIN
            RAISERROR('Error: La consistencia de cuotas es invalida (Nro: %d, Total: %d).', 16, 1, @targetNroCuota, @targetTotalCuotas);
            RETURN -5;
        END
    END
    
    -- validamos q no exista otro gasto con el mismo numero de factura para la misma empresa
    IF @nroFactura IS NOT NULL OR @nomEmpresa IS NOT NULL
    BEGIN
        DECLARE @currentNroFactura INT, @currentNomEmpresa VARCHAR(40);
        SELECT @currentNroFactura = nroFactura, @currentNomEmpresa = nomEmpresa FROM consorcio.gasto_extra_ordinario WHERE idGastoExtraOrd = @idGastoExtraOrd;
        
        DECLARE @targetNroFactura INT = ISNULL(@nroFactura, @currentNroFactura);
        DECLARE @targetNomEmpresa VARCHAR(40) = ISNULL(@nomEmpresa, @currentNomEmpresa);

        IF EXISTS (SELECT 1 FROM consorcio.gasto_extra_ordinario 
                   WHERE nroFactura = @targetNroFactura 
                   AND nomEmpresa = @targetNomEmpresa
                   AND idGastoExtraOrd <> @idGastoExtraOrd)
        BEGIN
            RAISERROR('Error: La combinacion Nro. Factura (%d) y Empresa (%s) ya existe en otro gasto extraordinario.', 16, 1, @targetNroFactura, @targetNomEmpresa);
            RETURN -6;
        END
    END
    
    BEGIN TRY
        UPDATE consorcio.gasto_extra_ordinario
        SET
            idGasto = ISNULL(@idGasto, idGasto),
            tipoGasto = ISNULL(LOWER(@tipoGasto), tipoGasto),
            nomEmpresa = ISNULL(@nomEmpresa, nomEmpresa),
            nroFactura = ISNULL(@nroFactura, nroFactura),
            descripcion = ISNULL(@descripcion, descripcion),
            nroCuota = ISNULL(@nroCuota, nroCuota),
            totalCuotas = ISNULL(@totalCuotas, totalCuotas),
            importe = ISNULL(@importe, importe)
        WHERE
            idGastoExtraOrd = @idGastoExtraOrd;

        PRINT 'Gasto Extraordinario ID: ' + CAST(@idGastoExtraOrd AS VARCHAR) + ' actualizado con exito.';
        RETURN 0;

    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR('Error inesperado al actualizar el gasto extraordinario: %s', 16, 1, @ErrorMessage);
        RETURN -7;
    END CATCH

    SET NOCOUNT OFF;
END;
GO

--------------------------------
--ELIMINAR GASTO EXTRA ORDINARIO
--------------------------------
CREATE OR ALTER PROCEDURE consorcio.sp_eliminarGastoExtraOrdinario
    @idGastoExtraOrd INT
AS
BEGIN
    SET NOCOUNT ON;

    -- validamos q exista el gasto y cargamos su padre
    DECLARE @currentIdGasto INT;
    SELECT @currentIdGasto = idGasto FROM consorcio.gasto_extra_ordinario WHERE idGastoExtraOrd = @idGastoExtraOrd;
    
    IF @currentIdGasto IS NULL
    BEGIN
        RAISERROR('Error: El Gasto Extraordinario de ID %d no existe. No se puede eliminar.', 16, 1, @idGastoExtraOrd);
        RETURN -1;
    END

    -- si la expensa ya tiene detalle, no se puede eliminar el gasto
    DECLARE @idExpensaPadre INT;
    SELECT @idExpensaPadre = idExpensa FROM consorcio.gasto WHERE idGasto = @currentIdGasto;

    IF EXISTS (SELECT 1 FROM consorcio.detalle_expensa WHERE idExpensa = @idExpensaPadre)
    BEGIN
        RAISERROR('Error: No se puede eliminar el Gasto Extraordinario ID %d. Ya se emitiio un detalle para la expensa de ID %d.', 16, 1, @idGastoExtraOrd, @idExpensaPadre);
        RETURN -2;
    END
    
    BEGIN TRY
        DELETE FROM consorcio.gasto_extra_ordinario
        WHERE idGastoExtraOrd = @idGastoExtraOrd;

        PRINT 'Gasto Extraordinario con ID: ' + CAST(@idGastoExtraOrd AS VARCHAR) + ' eliminado con exito.';
        RETURN 0;

    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR('Error inesperado al eliminar el gasto extraordinario: %s', 16, 1, @ErrorMessage);
        RETURN -3;
    END CATCH

    SET NOCOUNT OFF;
END;
GO