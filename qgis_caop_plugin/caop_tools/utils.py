# -*- coding: utf-8 -*-

"""
***************************************************************************
    utils.py
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
__date__ = "September 2023"
__copyright__ = "(C) 2023, NaturalGIS"

import os

from qgis.core import (
    Qgis,
    QgsFeatureRequest,
    QgsGeometry,
    QgsPointXY,
    QgsUnsetAttributeValue,
    QgsVectorLayerUtils,
    qgsDoubleNear,
)


def split_features(layer, curve, preserve_circular, topological_editing):
    if not layer.isSpatial():
        return Qgis.GeometryOperationResult.InvalidBaseGeometry

    result = Qgis.GeometryOperationResult.Success
    number_of_split_features = 0

    selected_ids = layer.selectedFeatureIds()
    preserve_circular &= curve.hasCurvedSegments()

    if len(selected_ids) > 0:
        features = layer.getSelectedFeatures()
    else:
        bbox = curve.boundingBox()
        if bbox.isEmpty():
            if bbox.width() == 0.0 and bbox.height() > 0:
                bbox.setXMinimum(bbox.xMinimum() - bbox.height() / 2)
                bbox.setXMaximum(bbox.xMaximum() + bbox.height() / 2)
            elif bbox.height() == 0.0 and bbox.width() > 0:
                bbox.setYMinimum(bbox.yMinimum() - bbox.width() / 2)
                bbox.setYMaximum(bbox.yMaximum() + bbox.width() / 2)
            else:
                buffer_distance = 0.000001
                if layer.crs().isGeographic():
                    buffer_distance = 0.00000001

                bbox.setXMinimum(bbox.xMinimum() - buffer_distance)
                bbox.setXMaximum(bbox.xMaximum() + buffer_distance)
                bbox.setYMinimum(bbox.yMinimum() - buffer_distance)
                bbox.setYMaximum(bbox.yMaximum() + buffer_distance)

        features = layer.getFeatures(
            QgsFeatureRequest()
            .setFilterRect(bbox)
            .setFlags(QgsFeatureRequest.ExactIntersect)
        )

    topology_test_points = list()
    features_data_to_add = list()
    field_count = layer.fields().count()
    for feat in features:
        if not feat.hasGeometry():
            continue

        original_geom = feat.geometry()
        feature_geom = QgsGeometry(original_geom)
        split_points = [QgsPointXY(p) for p in curve.points()]
        (
            split_function_return,
            new_geometries,
            feature_topology_test_points,
        ) = feature_geom.splitGeometry(
            split_points, preserve_circular, topological_editing
        )
        topology_test_points.append(feature_topology_test_points)
        if split_function_return == Qgis.GeometryOperationResult.Success:
            for geom in new_geometries:
                attribute_map = dict()
                for field_idx in range(field_count):
                    field = layer.fields().at(field_idx)
                    if field.name() == "troco_parente":
                        if feat.attribute("identificador") == "uuid_generate_v1mc()":
                            pass
                        else:
                            attribute_map[field_idx] = feat.attribute("identificador")
                            continue
                    else:
                        attribute_map[field_idx] = feat.attribute(field_idx)

                features_data_to_add.append(
                    QgsVectorLayerUtils.QgsFeatureData(geom, attribute_map)
                )

            if topological_editing:
                for p in feature_topology_test_points:
                    add_topological_points(layer, p)

            number_of_split_features += 1
            layer.deleteFeature(feat.id())
        elif split_function_return not in (
            Qgis.GeometryOperationResult.Success,
            Qgis.GeometryOperationResult.NothingHappened,
        ):
            result = split_function_return

    if len(features_data_to_add) > 0:
        features_list_to_add = QgsVectorLayerUtils.createFeatures(
            layer, features_data_to_add
        )
        layer.addFeatures(features_list_to_add)

    if number_of_split_features == 0:
        result = Qgis.GeometryOperationResult.NothingHappened

    return result, topology_test_points


def add_topological_points(layer, p):
    if not layer.isSpatial():
        return 1

    segment_search_epsilon = 1e-12 if layer.crs().isGeographic() else 1e-8
    threshold = layer.geometryOptions().geometryPrecision()

    if qgsDoubleNear(threshold, 0.0):
        threshold = 0.0000001
        if layer.crs().mapUnits() == Qgis.DistanceUnit.Meters:
            threshold = 0.001
        elif layer.crs().mapUnits() == Qgis.DistanceUnit.Feet:
            threshold = 0.0001

    search_rect = QgsRectangle(
        p.x() - threshold, p.y() - threshold, p.x() + threshold, p.y() + threshold
    )
    sqr_snapping_tolerance = threshold * threshold

    fit = layer.getFeatures(
        QgsFeatureRequest()
        .setFilterRect(search_rect)
        .setFlags(QgsFeatureRequest.ExactIntersect)
        .setNoAttributes()
    )
    features = dict()
    segments = dict()

    for f in fit:
        (
            sqr_dist_segment_snap,
            snapped_point,
            after_vertex,
            _,
        ) = f.geometry().closestSegmentWithContext(p, segment_search_epsilon)
        if sqr_dist_segment_snap < sqr_snapping_tolerance:
            segments[f.id()] = after_vertex
            features[f.id()] = f.geometry()

    if len(segments) == 0:
        return 2

    points_added = False
    for fid, segment_after_vertex in segments.items():
        geom = features[fid]
        (
            at_vertex,
            before_vertex,
            after_vertex,
            sqr_dist_vertex_snap,
        ) = geom.closestVertex(p)
        if sqr_dist_vertex_snap < sqr_snapping_tolerance:
            continue

        if not layer.insertVertex(p, fid, segment_after_vertex):
            pass
        else:
            points_added = True

    return 0 if pointsAdded else 2
