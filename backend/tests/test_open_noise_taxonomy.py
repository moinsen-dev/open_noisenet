"""Contract tests for mobile OpenNoiseNet taxonomy semantics."""

from datetime import timedelta

import pytest

from app.services.episode_engine import _class_family, _class_impact, _merge_gap


@pytest.mark.parametrize(
    ("label", "expected_family"),
    [
        ("loud_conversation", "speech"),
        ("shouting_or_dispute", "speech"),
        ("party_or_music_with_people", "environmental"),
        ("drilling", "environmental"),
        ("road_traffic", "environmental"),
        ("animals", "environmental"),
        ("furniture_movement", "impulsive"),
        ("footsteps_or_impact_noise", "impulsive"),
        ("door_or_impact", "impulsive"),
    ],
)
def test_mobile_taxonomy_maps_to_episode_families(
    label: str,
    expected_family: str,
) -> None:
    assert _class_family(label, "intermittent") == expected_family


def test_new_continuous_segments_keep_the_long_merge_gap() -> None:
    assert _class_family("unknown_sound_source", "continuous") == "continuous"
    assert _merge_gap("continuous", "continuous") == timedelta(minutes=10)
    assert _merge_gap("background_elevation", "continuous") == timedelta(
        minutes=10
    )


def test_mobile_taxonomy_has_explicit_impact_weights() -> None:
    assert _class_impact("hammering") > _class_impact("television_or_music")
    assert _class_impact("unknown_sound_source") == _class_impact("unknown_noise")
