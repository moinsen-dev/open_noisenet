"""Bounded metadata-only contract; no arbitrary text, audio, vectors or locations."""

import hashlib
import json
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, model_validator

TimeMs = int


class ActivityInterval(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True)
    start_ms: TimeMs = Field(ge=0, le=4102444800000)
    end_ms: TimeMs = Field(gt=0, le=4102444800000)


class SourcePhaseUpload(BaseModel):
    model_config = ConfigDict(extra="forbid")
    phase_id: UUID
    revision: int = Field(strict=True, ge=1, le=2147483647)
    algorithm: Literal["source_phases_v1"]
    source_model: Literal["yamnet_tflite_4d8b4a53"]
    family: Literal[
        "speech", "music", "tools", "traffic", "appliance", "animals", "impact"
    ]
    start_ms: int = Field(strict=True, ge=0, le=4102444800000)
    end_ms: int = Field(strict=True, gt=0, le=4102444800000)
    observed_until_ms: int = Field(strict=True, gt=0, le=4102444800000)
    active_ms: int = Field(strict=True, gt=0)
    pause_ms: int = Field(strict=True, ge=0)
    activity: list[ActivityInterval] = Field(min_length=1, max_length=20000)
    state: Literal["open", "closed", "interrupted"]
    end_reason: Literal[
        "end_of_observations",
        "pause_limit",
        "sparse_activity",
        "inference_gap",
        "sensor_stopped",
        "consent_stopped",
        "process_restart",
        "backend_changed",
    ]

    @model_validator(mode="after")
    def coherent_intervals(self):
        if (
            self.start_ms != self.activity[0].start_ms
            or self.end_ms != self.activity[-1].end_ms
        ):
            raise ValueError("Phase boundaries must match activity")
        previous = -1
        active = 0
        for part in self.activity:
            if part.start_ms <= previous or part.end_ms <= part.start_ms:
                raise ValueError("Activity must be sorted, disjoint and unioned")
            previous = part.end_ms
            active += part.end_ms - part.start_ms
        if (
            active != self.active_ms
            or self.pause_ms != self.end_ms - self.start_ms - active
            or self.observed_until_ms < self.end_ms
        ):
            raise ValueError("Inconsistent phase totals or coverage")
        expected = (
            "open"
            if self.end_reason == "end_of_observations"
            else (
                "interrupted"
                if self.end_reason
                in {"inference_gap", "process_restart", "backend_changed"}
                else "closed"
            )
        )
        if self.state != expected:
            raise ValueError("Inconsistent completion reason")
        return self

    def payload(self):
        return self.model_dump(mode="json")

    def digest(self):
        return hashlib.sha256(
            json.dumps(self.payload(), sort_keys=True, separators=(",", ":")).encode()
        ).hexdigest()
