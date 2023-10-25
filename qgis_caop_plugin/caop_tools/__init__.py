# -*- coding: utf-8 -*-

"""
***************************************************************************
    __init__.py
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


from caop_tools.plugin import CaopToolsPlugin


def classFactory(iface):
    return CaopToolsPlugin(iface)
