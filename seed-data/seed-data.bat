::@ECHO OFF
@echo off
setlocal enabledelayedexpansion

SET "mongoPath=C:\Program Files\MongoDB\Server\4.0\bin\mongoexport"
SET "distPath=E:\script-seed-data\db\"
SET "database=mylib"
SET "databasePath=localhost:27017"



set list=ActivityActions ActivityTransitions ActivityViewMaps Activitys^
	EntityColumnPermisssions Navigations^
	EmailTemplates FeatureEndPointMaps FeatureRoleMaps WorkflowSettings RoleHierarchys TagValidators UserReadableDatas^
	WorkflowNavigationPaths RoleHierarchys Entitys EntityDefaultPermissionSettingss CountryInfos

(for %%n in (%list%) do ( 
  %mongoPath% --host %databasePath% --db %database% --collection %%n --out %distPath%%%n.json
))



PAUSE