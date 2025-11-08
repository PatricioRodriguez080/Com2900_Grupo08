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
Enunciado:        "02 - Creación de indices"
===============================================================================
*/

USE Com2900G08;
GO

CREATE NONCLUSTERED INDEX idx_expensa_filtro_periodo
ON consorcio.expensa (idConsorcio, anio, periodo)
INCLUDE (idExpensa);
GO

CREATE NONCLUSTERED INDEX idx_detalle_expensa_expensa_montos
ON consorcio.detalle_expensa (idExpensa, idDetalleExpensa)
INCLUDE (totalAPagar, expensasOrdinarias, expensasExtraordinarias, interesPorMora, idUnidadFuncional);
GO

CREATE NONCLUSTERED INDEX idx_pago_detalle_expensa_fecha
ON consorcio.pago (idDetalleExpensa, fecha)
INCLUDE (importe);
GO

CREATE NONCLUSTERED INDEX idx_pago_cuenta_fecha
ON consorcio.pago (cuentaOrigen, fecha)
INCLUDE (importe);
GO

CREATE NONCLUSTERED INDEX idx_expensa_periodo_id
ON consorcio.expensa (anio, periodo)
INCLUDE (idExpensa);
GO

CREATE NONCLUSTERED INDEX idx_persona_unidad_funcional_rol_unidad_funcional_persona
ON consorcio.persona_unidad_funcional (rol, idUnidadFuncional)
INCLUDE (idPersona);
GO

CREATE NONCLUSTERED INDEX idx_detalle_expensa_unidad_funcional_deuda
ON consorcio.detalle_expensa (idUnidadFuncional)
INCLUDE (deuda);
GO

CREATE NONCLUSTERED INDEX idx_persona_salida
ON consorcio.persona (idPersona)
INCLUDE (nombre, apellido, dni, email, telefono);
GO

CREATE NONCLUSTERED INDEX idx_unidad_funcional_consorcio_output
ON consorcio.unidad_funcional (idConsorcio, idUnidadFuncional)
INCLUDE (piso, departamento);
GO