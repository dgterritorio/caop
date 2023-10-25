# -*- coding: utf-8 -*-

"""
***************************************************************************
    split_line_tool.py
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


from qgis.PyQt.QtCore import Qt

from qgis.gui import QgsMapToolCapture
from qgis.core import Qgis, QgsPointLocator, QgsProject
from qgis.utils import iface

from caop_tools.utils import split_features


class SplitLineTool(QgsMapToolCapture):
    def __init__(self, canvas, cad_dock):
        super().__init__(canvas, cad_dock, QgsMapToolCapture.CaptureLine)

        self.setSnapToLayerGridEnabled(False)

    def supportsTechnique(self, technique):
        if technique in (
            Qgis.CaptureTechnique.StraightSegments,
            Qgis.CaptureTechnique.CircularString,
            Qgis.CaptureTechnique.Streaming,
        ):
            return True

        return False

    def cadCanvasReleaseEvent(self, event):
        layer = self.canvas().currentLayer()

        if layer is None:
            self.notifyNotVectorLayer()
            return

        if not layer.isEditable():
            self.notifyNotEditableLayer()
            return

        split = False

        if event.button() == Qt.LeftButton:
            error = 0

            if (
                layer.geometryType() == Qgis.GeometryType.Line
                and len(self.pointsZM()) == 0
            ):
                m = (
                    self.canvas()
                    .snappingUtils()
                    .snapToCurrentLayer(event.pos(), QgsPointLocator.Vertex)
                )
                if m.isValid():
                    error = self.addVertex(event.mapPoint(), m)
                    split = True

            if not split:
                error = self.addVertex(event.mapPoint(), event.mapPointMatch())

            if error == 2:
                iface.messageBar().pushMessage(
                    self.tr("Coordinate transform error"),
                    self.tr(
                        "Cannot transform the point to the layers coordinate system"
                    ),
                    Qgis.MessageLevel.Info,
                )
                return

            self.startCapturing()
        elif event.button() == Qt.RightButton:
            if not split and self.size() < 2:
                self.stopCapturing()
                return

            split = True

        if split:
            self.deleteTempRubberBand()
            topological_editing = QgsProject.instance().topologicalEditing()
            layer.beginEditCommand(self.tr("CAOP features split"))

            curve = self.captureCurve().clone()
            curve.dropZValue()

            result, topology_test_points = split_features(
                layer, curve, True, topological_editing
            )

            if result == Qgis.GeometryOperationResult.Success:
                layer.endEditCommand()
            else:
                layer.destroyEditCommand()

            if result == Qgis.GeometryOperationResult.Success:
                if topological_editing and len(topology_test_points) > 0:
                    layers = self.canvas().layers(True)
                    for l in layers:
                        if (
                            l
                            and l.isEditable()
                            and l.isSpatial()
                            and l != layer
                            and l.geometryType()
                            in (Qgis.GeometryType.Line, Qgis.GeometryType.Polygon)
                        ):
                            l.beginEditCommand(
                                self.tr("Topological points from CAOP features split")
                            )
                            res = l.addTopologicalPoints(topology_test_points)
                            if res == 0:
                                l.endEditCommand()
                            else:
                                l.destroyEditCommand()
            elif result == Qgis.GeometryOperationResult.NothingHappened:
                iface.messageBar().pushMessage(
                    self.tr("No features were split"),
                    self.tr(
                        "If there are selected features, the split tool only "
                        "applies to those. If you would like to split all "
                        "features under the split line, clear the selection."
                    ),
                    Qgis.MessageLevel.Warning,
                )
            elif result == Qgis.GeometryOperationResult.GeometryEngineError:
                iface.messageBar().pushMessage(
                    self.tr("No feature split done"),
                    self.tr(
                        "Cut edges detected. Make sure the line splits features "
                        "into multiple parts."
                    ),
                    Qgis.MessageLevel.Warning,
                )
            elif result == Qgis.GeometryOperationResult.InvalidBaseGeometry:
                iface.messageBar().pushMessage(
                    self.tr("No feature split done"),
                    self.tr(
                        "The geometry is invalid. Please repair before trying "
                        "to split it."
                    ),
                    Qgis.MessageLevel.Warning,
                )
            else:
                iface.messageBar().pushMessage(
                    self.tr("No feature split done"),
                    self.tr("An error occurred during splitting."),
                    Qgis.MessageLevel.Warning,
                )

            self.stopCapturing()
