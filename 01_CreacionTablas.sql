/*
-----------------------------------------------------------------
Materia:         Bases de Datos Aplicadas
Comisión:        Com 01-2900
Grupo:           G08
Fecha de Entrega: 25/10/2025
Integrantes:
    Bentancur Suarez, Ismael 45823439
    Rodriguez Arrien, Juan Manuel 44259478
    Rodriguez, Patricio 45683229
    Ruiz, Leonel Emiliano 45537914
Enunciado:       "01 - Creación de Tablas"
-----------------------------------------------------------------
*/

IF NOT EXISTS (SELECT * FROM  sys.schemas WHERE name = 'consorcio')
    EXEC('CREATE SCHEMA consorcio');
go

DROP TABLE IF EXISTS consorcio.persona;
DROP TABLE IF EXISTS consorcio.persona_unidad_funcional;
go

CREATE TABLE consorcio.gasto (
    idGasto INT IDENTITY(1,1),
    idExpensa INT NOT NULL,
    periodo VARCHAR(12) NOT NULL,
    subTotalOrdinarios DECIMAL(12,2) NOT NULL,
    subTotalExtraOrd DECIMAL(12,2) NOT NULL,

    CONSTRAINT pk_gasto PRIMARY KEY (idGasto),
    CONSTRAINT chk_periodo_gasto CHECK (periodo IN('enero','febrero','marzo','abril','mayo','junio','julio','agosto','septiembre','octubre','noviembre','diciembre')),
    CONSTRAINT chk_subTotalOrd_gasto CHECK (subTotalOrdinarios >= 0),
    CONSTRAINT chk_subTotalExtraOrd_gasto CHECK (subTotalExtraOrd >= 0),
    CONSTRAINT fk_gasto_expensa FOREIGN KEY (idExpensa) REFERENCES consorcio.expensa(idExpensa)
);

CREATE TABLE consorcio.gasto_ordinario (
    idGastoOrd INT IDENTITY(1,1),
    idGasto INT NOT NULL,
    tipoGasto VARCHAR(20) NOT NULL,
    subTipoGasto VARCHAR(30) NOT NULL,
    nomEmpresa VARCHAR(40) NOT NULL,
    nroFactura INT NOT NULL,
    importe DECIMAL(12,2) NOT NULL,

    CONSTRAINT pk_gastoOrd PRIMARY KEY (idGastoOrd),
    CONSTRAINT chk_tipoGasto_ord CHECK (tipoGasto IN ('mantenimiento','limpieza','administracion','seguros','generales','servicios publicos')),
    CONSTRAINT chk_importe_ord CHECK (importe > 0),
    CONSTRAINT uq_factura_ord UNIQUE (nroFactura, nomEmpresa),
    CONSTRAINT fk_gastoOrd_gasto FOREIGN KEY (idGasto) REFERENCES consorcio.gasto(idGasto)
);

CREATE TABLE consorcio.gasto_extra_ordinario (
    idGastoExtraOrd INT IDENTITY(1,1),
    idGasto INT NOT NULL,
    tipoGasto VARCHAR(12) NOT NULL,
    nomEmpresa VARCHAR(40) NOT NULL,
    nroFactura INT NOT NULL,
    descripcion VARCHAR(50) NOT NULL,
    nroCuota INT NOT NULL,
    totalCuotas INT NOT NULL,
    importe DECIMAL(12,2) NOT NULL,

    CONSTRAINT pk_gastoExtraOrd PRIMARY KEY (idGastoExtraOrd),
    CONSTRAINT chk_tipoGasto_extraOrd CHECK (tipoGasto IN ('reparacion','construccion')),
    CONSTRAINT chk_nroCuota CHECK (nroCuota > 0),
    CONSTRAINT chk_totalCuotas CHECK (totalCuotas > 0),
    CONSTRAINT chk_importe_extraOrd CHECK (importe > 0),
    CONSTRAINT chk_cuotas_validas CHECK (nroCuota <= totalCuotas),
    CONSTRAINT uq_factura_extra_ord UNIQUE (nroFactura, nomEmpresa),
    CONSTRAINT fk_gastoExtraOrd_gasto FOREIGN KEY (idGasto) REFERENCES consorcio.gasto(idGasto)
);

CREATE TABLE consorcio.persona (
    idPersona int identity(1,1) PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL,
    apellido VARCHAR(50) NOT NULL,
    dni int NOT NULL UNIQUE,
    email VARCHAR(100) NULL,
    telefono VARCHAR(20) NULL,
    cuentaOrigen CHAR(22) NOT NULL,

    CONSTRAINT chk_pago_cuentaOrigen CHECK (ISNUMERIC(cuentaOrigen) = 1)
);

CREATE TABLE consorcio.persona_unidad_funcional(
    idPersona int NOT NULL,
    idUnidadFuncional int NOT NULL,
    rol VARCHAR(15) NOT NULL,

    CONSTRAINT pk_personaUnidadFuncional PRIMARY KEY (idPersona, idUnidadFuncional, rol),
    CONSTRAINT fk_idPersona FOREIGN KEY (idPersona) REFERENCES consorcio.persona (idPersona),
    CONSTRAINT fk_idUnidadFuncional FOREIGN KEY (idUnidadFuncional) REFERENCES consorcio.unidad_funcional (idUnidadFuncional),
    CONSTRAINT chk_rol CHECK (rol IN ('propietario', 'inquilino'))
);
go