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
    QgsProject,
    QgsFeature,
    QgsDataSourceUri,
    QgsVectorLayerUtils,
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
    features_data_to_add = dict()
    child_features = dict()
    field_count = layer.fields().count()
    relations = QgsProject.instance().relationManager().referencedRelations(layer)
    for feat in features:
        if not feat.hasGeometry():
            continue

        original_geom = feat.geometry()
        feature_geom = QgsGeometry(original_geom)
        # splitFeature=False: keep feature_geom intact and return every part in new_geometries
        (
            split_function_return,
            new_geometries,
            feature_topology_test_points,
        ) = feature_geom.splitGeometry(
            curve, preserve_circular, topological_editing, False
        )
        topology_test_points.extend(feature_topology_test_points)
        if split_function_return == Qgis.GeometryOperationResult.Success:
            for geom in new_geometries:
                attribute_map = dict()
                for field_idx in range(field_count):
                    field = layer.fields().at(field_idx)
                    if field.name() == "troco_parente":
                        if is_new_feature(feat.attribute("identificador"), layer):
                            attribute_map[field_idx] = feat.attribute("troco_parente")
                        else:
                            attribute_map[field_idx] = (
                                feat.attribute("identificador")
                                if not feat.attribute("troco_parente")
                                else feat.attribute("troco_parente")
                            )
                    else:
                        attribute_map[field_idx] = feat.attribute(field_idx)

                if feat.id() not in features_data_to_add:
                    features_data_to_add[feat.id()] = [
                        QgsVectorLayerUtils.QgsFeatureData(geom, attribute_map)
                    ]
                else:
                    features_data_to_add[feat.id()].append(
                        QgsVectorLayerUtils.QgsFeatureData(geom, attribute_map)
                    )

            if topological_editing:
                layer.addTopologicalPoints(feature_topology_test_points)

            number_of_split_features += 1

            for r in relations:
                it = r.getRelatedFeatures(feat)
                childs = list()
                for f in it:
                    childs.append(QgsFeature(f))
                child_features[(r.id(), feat.id())] = childs
            layer.deleteFeature(feat.id())
        elif split_function_return not in (
            Qgis.GeometryOperationResult.Success,
            Qgis.GeometryOperationResult.NothingHappened,
        ):
            result = split_function_return

    for parent_fid, data_to_add in features_data_to_add.items():
        features_list_to_add = QgsVectorLayerUtils.createFeatures(layer, data_to_add)
        for f in features_list_to_add:
            for r in relations:
                if (r.id(), parent_fid) in child_features:
                    if not r.referencingLayer().isEditable():
                        if not r.referencingLayer().startEditing():
                            # TODO: handle errors
                            pass

                    child_fields_count = r.referencingLayer().fields().count()
                    key_field = QgsDataSourceUri(
                        r.referencingLayer().source()
                    ).keyColumn()
                    keys = r.fieldPairs()
                    new_childs = list()
                    for cf in child_features[(r.id(), parent_fid)]:
                        attr_map = dict()

                        for i in range(child_fields_count):
                            attr_map[i] = cf.attribute(i)

                        for k, v in keys.items():
                            attr_map[cf.fieldNameIndex(k)] = f[v]

                        new_childs.append(
                            QgsVectorLayerUtils.QgsFeatureData(cf.geometry(), attr_map)
                        )

                    child_features_to_add = QgsVectorLayerUtils.createFeatures(
                        r.referencingLayer(), new_childs
                    )
                    r.referencingLayer().addFeatures(child_features_to_add)

        layer.addFeatures(features_list_to_add)

    if number_of_split_features == 0:
        result = Qgis.GeometryOperationResult.NothingHappened

    return result, topology_test_points


def is_new_feature(fid, layer):
    if not layer.isEditable():
        return False
    buff = layer.editBuffer()
    for f in buff.addedFeatures().values():
        if f["identificador"] == fid:
            return True
    return False
