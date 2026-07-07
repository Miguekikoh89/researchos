# Hotfix de certificación numérica — cuatro fallos

1. Las pruebas de correlación y confiabilidad cargan `helpers.R` antes de `statistics.R`, igual que el motor real.
2. La normalización de encabezados bootstrap PLS convierte primero a minúsculas; así reconoce `Original Est.`, `Bootstrap SD`, `2.5% CI` y `97.5% CI`.
3. ANCOVA calcula medias marginales estimadas, errores estándar, IC y contrastes con la matriz del modelo `lm`, sin dependencia obligatoria de `emmeans`.
4. El instalador diferencia dependencias obligatorias y opcionales y falla únicamente si falta una dependencia del núcleo certificado.
