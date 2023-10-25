# -*- coding: utf-8 -*-

"""
***************************************************************************
    plugin.py
    ---------------------
    Date                 : October 2023
    Copyright            : (C) 2023 by NaturalGIS
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
__date__ = "October 2023"
__copyright__ = "(C) 2023, NaturalGIS"


import os

from qgis.PyQt.QtCore import QCoreApplication, QTranslator

from qgis.core import QgsApplication


plugin_path = os.path.dirname(__file__)


class CaopToolsPlugin:
    def __init__(self, iface):
        self.iface = iface

        locale = QgsApplication.locale()
        qmPath = os.path.join(plugin_path, "i18n", f"caoptools_{locale}.qm")

        if os.path.exists(qmPath):
            self.translator = QTranslator()
            self.translator.load(qmPath)
            QCoreApplication.installTranslator(self.translator)

    def initGui(self):
        pass

    def unload(self):
        pass

    def tr(self, text):
        return QCoreApplication.translate(self.__class__.__name__, text)
