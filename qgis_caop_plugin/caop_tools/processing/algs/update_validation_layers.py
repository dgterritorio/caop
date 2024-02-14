# -*- coding: utf-8 -*-

"""
***************************************************************************
    update_validation_layers.py
    ---------------------
    Date                 : February 2024
    Copyright            : (C) 2024 by NaturalGIS
    Email                : info at naturalgis dot pt
***************************************************************************
*                                                                         *
*   This program is free software; you can redistribute it and/or modify  *
*   it under the terms of the GNU General Public License as published by  *
*   the Free Software Foundation; either version 2 of the License, or     *
*   (at your option) any later version.                                   *
*                                                                         *
***************************************************************************
"""

__author__ = "NaturalGIS"
__date__ = "February 2024"
__copyright__ = "(C) 2024, NaturalGIS"


from qgis.PyQt.QtCore import QCoreApplication

from qgis.core import (
    QgsProviderRegistry,
    QgsProviderConnectionException,
    QgsProcessingAlgorithm,
    QgsProcessingException,
    QgsProcessingParameterProviderConnection,
    QgsProcessingParameterEnum,
)


class UpdateValidationLayers(QgsProcessingAlgorithm):

    CONNECTION = "CONNECTION"
    REGION = "REGION"

    def name(self):
        return "updatevalidationlayers"

    def displayName(self):
        return self.tr("Update validation layers")

    def group(self):
        return self.tr("Layer management")

    def groupId(self):
        return "layermanagement"

    def tr(self, text):
        return QCoreApplication.translate("caoptools", text)

    def __init__(self):
        super().__init__()

    def createInstance(self):
        return type(self)()

    def initAlgorithm(self, config=None):
        self.addParameter(
            QgsProcessingParameterProviderConnection(
                self.CONNECTION, self.tr("Database connection"), "postgres"
            )
        )

        self.regions = (
            (self.tr("Continental"), "cont"),
            (self.tr("Madeira Autonomous Region"), "ram"),
            (self.tr("Autonomous Region of the Azores - Western Group"), "raa_oci"),
            (
                self.tr("Autonomous Region of the Azores - Central and Eastern Group"),
                "raa_cen_ori",
            ),
        )
        self.addParameter(
            QgsProcessingParameterEnum(
                self.REGION, self.tr("Region to process"), [i[0] for i in self.regions]
            )
        )

    def processAlgorithm(self, parameters, context, feedback):
        conn_name = self.parameterAsConnectionName(parameters, self.CONNECTION, context)
        region = self.regions[self.parameterAsEnum(parameters, self.REGION, context)][1]

        try:
            md = QgsProviderRegistry.instance().providerMetadata("postgres")
            conn = md.createConnection(conn_name)
        except QgsProviderConnectionException as e:
            raise QgsProcessingException(
                self.tr(
                    "Could not retrieve connection details for {}".format(conn_name)
                )
            )

        try:
            conn.executeSql(f"SELECT public.actualizar_validacao('{region}')", feedback)
        except QgsProviderConnectionException as e:
            raise QgsProcessingException(
                self.tr("Error executing database function: {}".format(e))
            )

        return {}
