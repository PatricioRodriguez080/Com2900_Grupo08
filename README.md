## 👥 Integrantes

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
