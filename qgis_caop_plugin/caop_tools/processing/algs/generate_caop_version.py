# -*- coding: utf-8 -*-

"""
***************************************************************************
    generate_caop_version.py
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


import os

from qgis.PyQt.QtCore import QCoreApplication
from qgis.PyQt.QtGui import QIcon

from qgis.core import (
    QgsProviderRegistry,
    QgsProviderConnectionException,
    QgsProcessingAlgorithm,
    QgsProcessingException,
    QgsProcessingMultiStepFeedback,
    QgsProcessingParameterProviderConnection,
    QgsProcessingParameterEnum,
    QgsProcessingParameterString,
    QgsProcessingParameterDateTime,
)

plugin_path = os.path.split(os.path.dirname(__file__))[0]


class GenerateCaopVersion(QgsProcessingAlgorithm):

    CONNECTION = "CONNECTION"
    SCHEMA_NAME = "SCHEMA_NAME"
    REGION = "REGION"
    DATE = "DATE"

    def name(self):
        return "generatecaopversion"

    def displayName(self):
        return self.tr("Generate CAOP version")

    def group(self):
        return self.tr("Layer management")

    def groupId(self):
        return "layermanagement"

    def icon(self):
        return QIcon(os.path.join(plugin_path, "..", "icons", "generate-caop.svg"))

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
        self.addParameter(
            QgsProcessingParameterString(
                self.SCHEMA_NAME, self.tr("Output schema name")
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
        self.addParameter(
            QgsProcessingParameterDateTime(self.DATE, self.tr("Timestamp"))
        )

    def processAlgorithm(self, parameters, context, feedback):
        conn_name = self.parameterAsConnectionName(parameters, self.CONNECTION, context)
        schema_name = self.parameterAsString(parameters, self.SCHEMA_NAME, context)
        date_time = self.parameterAsDateTime(parameters, self.DATE, context)
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

        multi_feedback = QgsProcessingMultiStepFeedback(2, feedback)
        dt = date_time.toString("yyyy-MM-dd hh:mm:ss")

        try:
            conn.executeSql(
                f"SELECT public.gerar_poligonos_caop('{schema_name}', '{region}', '{dt}' )",
                multi_feedback,
            )
            multi_feedback.setCurrentStep(1)
            conn.executeSql(
                f"SELECT gerar_trocos_caop('{schema_name}', '{region}', '{dt}')",
                multi_feedback,
            )
            multi_feedback.setCurrentStep(2)
        except QgsProviderConnectionException as e:
            raise QgsProcessingException(
                self.tr("Error executing database function: {}".format(e))
            )

        return {}
