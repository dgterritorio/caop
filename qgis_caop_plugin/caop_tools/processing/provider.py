# -*- coding: utf-8 -*-

"""
***************************************************************************
    provider.py
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

from qgis.PyQt.QtGui import QIcon
from qgis.PyQt.QtCore import QCoreApplication

from qgis.core import QgsProcessingProvider

from caop_tools.processing.algs.update_master_outputs import UpdateMasterOutputs
from caop_tools.processing.algs.update_validation_layers import UpdateValidationLayers
from caop_tools.processing.algs.generate_caop_version import GenerateCaopVersion

plugin_path = os.path.split(os.path.dirname(__file__))[0]


class CaopToolsProvider(QgsProcessingProvider):
    def __init__(self):
        super().__init__()

    def id(self):
        return "caoptools"

    def name(self):
        return "CAOP Tools"

    def icon(self):
        return QIcon(os.path.join(plugin_path, "icons", "caop.svg"))

    def load(self):
        self.refreshAlgorithms()
        return True

    def unload(self):
        pass

    def loadAlgorithms(self):
        algs = [UpdateMasterOutputs(), UpdateValidationLayers(), GenerateCaopVersion()]
        for a in algs:
            self.addAlgorithm(a)

    def tr(self, string):
        return QCoreApplication.translate(self.__class__.__name__, string)
