#!/usr/bin/env bash

lrelease qgis_caop_plugin/caop_tools/i18n/*.ts
(cd qgis_caop_plugin && zip -r -9 ../caop_tools.zip caop_tools -x "**/__pycache__/*" "caop_tools/i18n/*.ts")
rm -vf qgis_caop_plugin/caop_tools/i18n/*.qm
