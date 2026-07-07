# Nota de trazabilidad — 12_cluster_PGV_IER_TV3_k3

Fecha de esta nota: 2026-07-06

## Hallazgo
`SELECTED_RESULT.json` en esta carpeta es byte-idéntico al resultado guardado en:
  AUDIT/real_data_384/production_phase4c_corrected/results/12_cluster_PGV_IER_TV3_k3/12_cluster_PGV_IER_TV3_k3__c1/result.json

El config que realmente produjo ese resultado es:
  AUDIT/real_data_384/production_phase4c_corrected/configs/12_cluster_PGV_IER_TV3_k3__c1.json
  (var_a = {name: "ClusterVars", items: ["PGV","IER","TV3"]})

El config preservado en esta carpeta (production_phase4a_extended/configs/12_cluster_PGV_IER_TV3_k3__c1.json)
corresponde a una version anterior/no corregida (var_a = {name:"PGV", items:["PGV"]}, con un
campo cluster_vars no leido por run_analysis.R) y NO reproduce SELECTED_RESULT.json.

## Diagnostico
- cluster_vars nunca fue implementado en ningun commit de run_analysis.R (confirmado via
  git log --all -S"cluster_vars", 0 resultados en todo el historial).
- run_cluster() soporta clustering multivariado desde el commit inicial 915066d.
- No hay regresion de codigo. Clasificacion: D (referencia con trazabilidad incompleta),
  sin componente B (regresion de enrutamiento).

## Para reproducir SELECTED_RESULT.json hoy
Usar el config de production_phase4c_corrected, no el de esta carpeta:
  Rscript apps/api/stats-engine-r/run_analysis.R \
    AUDIT/real_data_384/production_phase4c_corrected/configs/12_cluster_PGV_IER_TV3_k3__c1.json \
    <output_dir>

## Estado de este hallazgo
Diagnosticado en sesion de auditoria 2026-07-06. Ningun archivo historico fue modificado
(ni configs, ni SELECTED_RESULT.json, ni SELECTED_CANDIDATE.txt, ni result.json, ni codigo
fuente). Esta nota es un artefacto nuevo, puramente aditivo.

Ver .runtime/auditoria_188_lectura_20260706/ para el detalle completo de la auditoria que
origino este hallazgo, incluyendo la correccion de baremos de items individuales aplicada
en la misma sesion (no relacionada con este hallazgo de cluster).

## Alcance de esta nota
Este documento NO certifica 188/188. Es exclusivamente una aclaracion de procedencia para
el metodo de cluster. El estado de certificacion global de la auditoria 2026-07-06 se
documenta por separado y no debe inferirse a partir de esta nota.
