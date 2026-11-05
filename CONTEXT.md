# OpenNoiseNet Monitoring Context

OpenNoiseNet describes privacy-preserving observations of environmental sound. The language separates what a sensor measured, what the system inferred, and what a person later confirmed.

## Observations

**Source Segment**:
A bounded interval in which the classifier found continuous evidence for the same acoustic source category.
_Avoid_: Recording, clip, sound file

**Noise Event**:
A measured interval that satisfied a level or pattern rule and carries derived acoustic evidence. It may represent only one part of a longer real-world occurrence.
_Avoid_: Incident, episode, recording

**Noise Episode**:
One real-world noise occurrence composed of one or more related Noise Events. Brief pauses or Coverage Gaps may exist inside an episode and remain explicit.
_Avoid_: Event group, continuous recording

**Sensor Run**:
One uninterrupted period in which a device captured measurements. An app update, reboot, or capture restart ends the current run.
_Avoid_: Session, episode

**Coverage Gap**:
An interval for which the system has no measurement evidence. A Coverage Gap is never treated as proof of silence or continuous noise.
_Avoid_: Quiet period, silence

## Context and review

**Context Annotation**:
A human-supplied explanation for a Noise Episode, such as a known Teams meeting. It supplements the model result without rewriting the measured evidence.
_Avoid_: Ground-truth model label, automatic classification

**Local Activity**:
A sound produced within the monitored household or room rather than by the external environment of interest. It is excluded from external-exposure summaries only after confirmation or another explicit rule.
_Avoid_: False positive, irrelevant noise

**Target Source**:
An acoustic source category that a particular Sensor Placement is intended to observe, such as road traffic, construction, or courtyard parties.
_Avoid_: Global filter, guaranteed source

## Deployment

**Monitoring Site**:
The physical property or building within which observations are compared.
_Avoid_: Device, address pin

**Monitoring Zone**:
An acoustically distinct area within a Monitoring Site, such as an office window or a bedroom facing a courtyard.
_Avoid_: Room name, device group

**Sensor Placement**:
A device's stable position, orientation, power arrangement, and acoustic surroundings within a Monitoring Zone. Moving a device starts a new placement for comparability purposes.
_Avoid_: Device identity, location alone

**Measurement Quality**:
The declared confidence boundary of a measurement, including calibration and placement limitations. Screening estimates are not official calibrated measurements.
_Avoid_: Accuracy guarantee, legal proof
