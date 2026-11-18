"""Roca base de los cristales de la mina.

El mineral que ve cada jugador (su propio diseño) se coloca encima de esta roca desde el juego;
los diseños de los 25 minerales están en minerals.py.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *  # noqa: F401,F403,E402


def build():
    reset_scene()
    rock = blob((5.2, 4.8, 3.6), seed=11)
    translate_bm(rock, (0, 0, 1.2))
    obj, tint, material = to_obj("rock", rock, (0.47, 0.46, 0.5), 0.05, 1, (120, 118, 125), "Slate")
    export_asset("crystal_node", [(obj, tint, material)])


build()
print("ROCA LISTA")
