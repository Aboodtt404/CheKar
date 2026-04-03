import pytest
from carcheck.costs.estimator import estimate_repair_cost


def test_dent_cost_cairo():
    cost = estimate_repair_cost("dent", region="cairo")
    assert cost is not None
    assert cost["min"] == 500
    assert cost["max"] == 1500


def test_scratch_cost_alexandria():
    cost = estimate_repair_cost("scratch", region="alexandria")
    assert cost is not None
    assert cost["min"] > 0


def test_unknown_damage_returns_none():
    cost = estimate_repair_cost("nonexistent_damage", region="cairo")
    assert cost is None


def test_unknown_region_falls_back_to_cairo():
    cost = estimate_repair_cost("dent", region="mansoura")
    assert cost is not None
    assert cost["min"] == 500


def test_all_damage_types_have_costs():
    for damage_type in ["dent", "scratch", "crack", "glass_shatter", "lamp_broken", "tire_flat"]:
        cost = estimate_repair_cost(damage_type, region="cairo")
        assert cost is not None, f"Missing cost for {damage_type}"
        assert cost["min"] > 0
        assert cost["max"] > cost["min"]
