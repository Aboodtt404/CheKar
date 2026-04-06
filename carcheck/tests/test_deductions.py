from carcheck.scoring.deductions import (
    get_body_deduction,
    get_accident_deduction,
    get_flood_deduction,
    get_mechanical_deduction,
    get_docs_deduction,
)
from carcheck.models import Severity


def test_body_minor_dent():
    assert get_body_deduction("dent", Severity.MINOR) == 3


def test_body_major_dent():
    assert get_body_deduction("dent", Severity.MAJOR) == 8


def test_body_crack_always_7():
    assert get_body_deduction("crack", Severity.MINOR) == 7
    assert get_body_deduction("crack", Severity.MAJOR) == 7


def test_body_unknown_class():
    assert get_body_deduction("unknown_class", Severity.MINOR) == 0


def test_accident_repaint_low():
    assert get_accident_deduction("repaint_possible") == 15


def test_accident_repaint_likely():
    assert get_accident_deduction("repaint_likely") == 30


def test_flood_water_stain():
    assert get_flood_deduction("water_stain") == 25


def test_flood_multiple():
    assert get_flood_deduction("multiple_indicators") == 40


def test_mechanical_oil_leak():
    assert get_mechanical_deduction("oil_leak") == 15


def test_docs_odometer_mismatch():
    assert get_docs_deduction("odometer_mismatch") == 30
