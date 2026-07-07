# Hotfix PLS-SEM: efectos indirectos específicos

- Se dejó de buscar `bootstrapped_indirect_paths`, objeto que `summary(boot_seminr_model)` no expone.
- Los efectos indirectos se calculan con el producto de rutas en cada remuestra de `boot_est$boot_paths`.
- El estimador original usa `boot_est$path_coef`.
- El IC primario es percentil bootstrap del 95%.
- El valor p es empírico bilateral por signo, coherente con `seminr::specific_effect_significance()`.
- Se enumeran caminos simples con uno a cuatro mediadores y se bloquean ciclos.
