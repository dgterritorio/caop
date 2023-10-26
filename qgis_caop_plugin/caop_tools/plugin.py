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

from qgis.PyQt.QtCore import Qt, QCoreApplication, QTranslator, QStringListModel
from qgis.PyQt.QtWidgets import QAction, QLineEdit, QCompleter
from qgis.PyQt.QtGui import QIcon

from qgis.core import (
    QgsApplication,
    QgsMapLayerType,
    QgsWkbTypes,
    Qgis,
    QgsExpressionContextUtils,
    QgsProject,
    QgsSettingsTree,
    QgsSettingsEntryStringList,
)

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
        self.settings_tree = QgsSettingsTree.createPluginTreeNode("caoptools")
        self.setting_motives = QgsSettingsEntryStringList("motives", self.settings_tree)

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

        motives = self.setting_motives.value()
        self.edit_comment = QLineEdit()
        self.motive_model = QStringListModel(motives)
        completer = QCompleter(self.motive_model, self.edit_comment)
        completer.setCaseSensitivity(Qt.CaseInsensitive)
        self.edit_comment.setCompleter(completer)
        self.edit_comment.editingFinished.connect(self.update_comment)
        self.toolbar.addWidget(self.edit_comment)

        if motives:
            self.edit_comment.setText(motives[0])

        self.tool_split = SplitLineTool(
            self.iface.mapCanvas(), self.iface.cadDockWidget()
        )
        self.tool_split.setAction(self.action_split)

        self.iface.projectRead.connect(self.update_comment)
        self.iface.newProjectCreated.connect(self.update_comment)

        self.iface.currentLayerChanged.connect(self.enable_actions)
        self.enable_actions(self.iface.activeLayer())

    def unload(self):
        QgsSettingsTree.unregisterPluginTreeNode("caoptools")

        self.iface.projectRead.disconnect(self.update_comment)
        self.iface.newProjectCreated.disconnect(self.update_comment)

        QgsExpressionContextUtils.removeProjectVariable(
            QgsProject.instance(), "dgt_motivo_edicao"
        )

        if self.iface.mapCanvas().mapTool() == self.tool_split:
            self.iface.mapCanvas().unsetMapTool(self.tool_split)

        del self.tool_split
        del self.toolbar

    def split_line(self):
        self.iface.mapCanvas().setMapTool(self.tool_split)

    def update_comment(self):
        comment = self.edit_comment.text()
        QgsExpressionContextUtils.setProjectVariable(
            QgsProject.instance(), "dgt_motivo_edicao", comment
        )
        motives = self.setting_motives.value()
        motives = [v for v in motives if v != comment]
        motives.insert(0, comment)
        self.setting_motives.setValue(motives[:5])
        self.motive_model.setStringList(motives[:5])

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
