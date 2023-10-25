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
from qgis.PyQt.QtWidgets import QAction
from qgis.PyQt.QtGui import QIcon

from qgis.core import QgsApplication, QgsMapLayerType, QgsWkbTypes, Qgis

from caop_tools.split_line_tool import SplitLineTool

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
        self.toolbar = self.iface.addToolBar(self.tr("CAOP Tools"))
        self.toolbar.setToolTip(self.tr("CAOP Tools"))
        self.toolbar.setObjectName("caopToolsToolBar")

        self.action_split = QAction(self.tr("Split features"), self.iface.mainWindow())
        self.action_split.setIcon(
            QIcon(os.path.join(plugin_path, "icons", "split_line.svg"))
        )
        self.action_split.setObjectName("caopSplitLineAction")
        self.action_split.setCheckable(True)
        self.action_split.triggered.connect(self.split_line)

        self.toolbar.addAction(self.action_split)

        self.tool_split = SplitLineTool(
            self.iface.mapCanvas(), self.iface.cadDockWidget()
        )
        self.tool_split.setAction(self.action_split)

        self.iface.currentLayerChanged.connect(self.enable_actions)
        self.enable_actions(self.iface.activeLayer())

    def unload(self):
        if self.iface.mapCanvas().mapTool() == self.tool_split:
            self.iface.mapCanvas().unsetMapTool(self.tool_split)

        del self.tool_split
        del self.toolbar

    def split_line(self):
        self.iface.mapCanvas().setMapTool(self.tool_split)

    def enable_actions(self, layer):
        if layer is None or layer.type() != QgsMapLayerType.Vector:
            self.action_split.setEnabled(False)
            return

        if QgsWkbTypes.flatType(layer.wkbType()) != Qgis.WkbType.LineString:
            self.action_split.setEnabled(False)
            return

        self.action_split.setEnabled(True)

    def tr(self, text):
        return QCoreApplication.translate(self.__class__.__name__, text)
