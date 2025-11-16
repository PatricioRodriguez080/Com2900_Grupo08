# 👥 Integrantes

| Nombre y Apellido              | Usuario de GitHub                         |
|-------------------------------|-------------------------------------------|
| Juan Manuel Rodriguez Arrien  | [@Zedraxx](https://github.com/Zedraxx)    |
| Ismael Bentancur Suarez      | [@Ismaelbentancur](https://github.com/Ismaelbentancur) |
| Patricio Rodriguez            | [@PatricioRodriguez080](https://github.com/PatricioRodriguez080) |
| Leonel Emiliano Ruiz            | [@LeoRuizz](https://github.com/LeoRuizz) |



# Norma de Nomenclatura del Proyecto

El equipo de desarrollo ha adoptado las siguientes convenciones de nomenclatura para garantizar la consistencia, legibilidad y el cumplimiento de las buenas prácticas en la base de datos (SQL Server) y el código.

| Elemento | Convención de Caso | Regla Clave | Ejemplo |
| :--- | :--- | :--- | :--- |
| **Tablas (Entidades)** | `snake_case` (minúsculas y guion bajo) | Siempre en **singular**. | `unidad_funcional` |
| **Store Procedures (SP)** | `snake_case` (minúsculas y guion bajo) | Descriptivo de la acción a realizar y prefijo SP. | `sp_calcular_morosidad` |
| **Columnas (Atributos)** | `camelCase` | Descriptivo. | `saldoAnterior`, `nroFactura` |
| **Variables/Parámetros** | `camelCase` | Descriptivo. | `@montoTotal`, `@idConsorcio` |
| **Índices** | `snake_case` (minúsculas y guion bajo) | Descriptivo y prefijo IDX con continuacion de tabla y campos incluidos. | `IDX_tabla_campos`, `IDX_pago_cuenta_fecha` |


# Uso de SQL Dinámico y Justificación

El SQL Dinámico se emplea en el proyecto para resolver requerimientos específicos relacionados con la **seguridad** y la **flexibilidad** en la manipulación de archivos.

---

### **Carga de Archivos y Rutas Dinámicas**

Se utiliza para la **carga de archivos** mediante los **Stored Procedures (SP)**, ya que se requiere que las **rutas de los archivos** sean pasadas como **parámetros**.

* Este *path dinámico* obliga a la utilización de SQL Dinámico para poder invocar las funciones de manejo de archivos de SQL Server como **`OPENROWSET`** y **`BULK INSERT`**. Esto permite que el SP pueda trabajar con cualquier ubicación de archivo especificada por el usuario en tiempo de ejecución.

---

### **Seguridad y Cifrado de Datos Sensibles**

El SQL Dinámico también se aplica en el **SP de seguridad** para el proceso de **cifrado de datos sensibles**.

* Su uso permite evitar que la **clave de encriptamiento** quede registrada en **posibles logs** del sistema o del servidor, aumentando así la seguridad al manejar la clave de manera transitoria y construida dinámicamente en memoria.

# **Consumo de API Externa (Argentina Datos)**

El proyecto también integra la API pública **[ArgentinaDatos](https://argentinadatos.com/)** para obtener información actualizada de:

* **Cotización del dólar**, utilizada en reportes.
* **Días feriados nacionales**, necesarios para la generacion de expensas con fechas ajustadas según el calendario oficial.
