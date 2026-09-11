#!/usr/bin/env python3
import ctypes
import json
import pathlib
import sys


def fail(message):
    raise SystemExit(f"error: {message}")


if len(sys.argv) != 3:
    fail("usage: native-smoke.py <runtime-root> <runtime-identifier>")

runtime_root = pathlib.Path(sys.argv[1]).resolve()
runtime_identifier = sys.argv[2]
with open(runtime_root / "manifest.json", encoding="utf-8") as source:
    manifest = json.load(source)
if manifest["rid"] != runtime_identifier:
    fail("manifest RID does not match the requested runtime")

native_path = runtime_root / manifest["nativeLibrary"]
library = ctypes.CDLL(str(native_path))

library.nlopt_version.argtypes = [
    ctypes.POINTER(ctypes.c_int),
    ctypes.POINTER(ctypes.c_int),
    ctypes.POINTER(ctypes.c_int),
]
major = ctypes.c_int()
minor = ctypes.c_int()
patch = ctypes.c_int()
library.nlopt_version(ctypes.byref(major), ctypes.byref(minor), ctypes.byref(patch))
if (major.value, minor.value, patch.value) != (2, 11, 0):
    fail(f"unexpected native version: {major.value}.{minor.value}.{patch.value}")

objective_type = ctypes.CFUNCTYPE(
    ctypes.c_double,
    ctypes.c_uint,
    ctypes.POINTER(ctypes.c_double),
    ctypes.POINTER(ctypes.c_double),
    ctypes.c_void_p,
)


@objective_type
def objective(dimensions, variables, gradient, data):
    if dimensions != 1:
        return float("nan")
    if gradient:
        gradient[0] = 2.0 * (variables[0] - 2.0)
    return (variables[0] - 2.0) ** 2


library.nlopt_create.argtypes = [ctypes.c_int, ctypes.c_uint]
library.nlopt_create.restype = ctypes.c_void_p
library.nlopt_destroy.argtypes = [ctypes.c_void_p]
library.nlopt_set_lower_bounds.argtypes = [ctypes.c_void_p, ctypes.POINTER(ctypes.c_double)]
library.nlopt_set_lower_bounds.restype = ctypes.c_int
library.nlopt_set_upper_bounds.argtypes = [ctypes.c_void_p, ctypes.POINTER(ctypes.c_double)]
library.nlopt_set_upper_bounds.restype = ctypes.c_int
library.nlopt_set_min_objective.argtypes = [ctypes.c_void_p, objective_type, ctypes.c_void_p]
library.nlopt_set_min_objective.restype = ctypes.c_int
library.nlopt_set_xtol_rel.argtypes = [ctypes.c_void_p, ctypes.c_double]
library.nlopt_set_xtol_rel.restype = ctypes.c_int
library.nlopt_set_maxeval.argtypes = [ctypes.c_void_p, ctypes.c_int]
library.nlopt_set_maxeval.restype = ctypes.c_int
library.nlopt_optimize.argtypes = [
    ctypes.c_void_p,
    ctypes.POINTER(ctypes.c_double),
    ctypes.POINTER(ctypes.c_double),
]
library.nlopt_optimize.restype = ctypes.c_int

optimizer = library.nlopt_create(25, 1)  # NLOPT_LN_COBYLA
if not optimizer:
    fail("nlopt_create returned a null handle")

try:
    lower = (ctypes.c_double * 1)(0.0)
    upper = (ctypes.c_double * 1)(4.0)
    for name, result in (
        ("lower bounds", library.nlopt_set_lower_bounds(optimizer, lower)),
        ("upper bounds", library.nlopt_set_upper_bounds(optimizer, upper)),
        ("objective", library.nlopt_set_min_objective(optimizer, objective, None)),
        ("relative parameter tolerance", library.nlopt_set_xtol_rel(optimizer, 1e-8)),
        ("maximum evaluations", library.nlopt_set_maxeval(optimizer, 200)),
    ):
        if result < 0:
            fail(f"NLopt rejected {name}: {result}")

    variables = (ctypes.c_double * 1)(0.5)
    optimum = ctypes.c_double()
    result = library.nlopt_optimize(optimizer, variables, ctypes.byref(optimum))
    if result <= 0:
        fail(f"basic COBYLA solve failed: {result}")
    if abs(variables[0] - 2.0) > 1e-5 or optimum.value > 1e-10:
        fail(f"unexpected optimum x={variables[0]} f={optimum.value}")
finally:
    library.nlopt_destroy(optimizer)

print(f"native-smoke: PASS ({runtime_identifier}, NLopt 2.11.0)")
