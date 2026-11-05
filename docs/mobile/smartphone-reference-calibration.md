# Smartphone reference calibration

This procedure creates a device-specific comparison offset for field pilots.
It does not certify a smartphone as a standards-compliant sound level meter.
The current mobile DSP still needs validated frequency-domain A-weighting.

## Required equipment

- A calibrated reference sound level meter that can report unweighted `LZeq`
- A stable stand so the phone and reference microphone do not move
- A steady broadband source such as calibrated pink noise
- A quiet indoor setup without reflective objects immediately beside either
  microphone

Do not derive calibration from an assumed room level, another uncalibrated
phone, or a generic offset for the phone model.

## Measurement procedure

1. Place the reference microphone and phone microphone beside one another at
   the same height and orientation. Do not place one behind the other.
2. Let both devices acclimatize and confirm that neither input is clipping.
3. Measure at a steady target around 60 dB for at least 60 seconds. With the
   sensor running, use **Settings → Audio Calibration → Measure 60 seconds**
   over the same interval as the reference meter. The experimental comparison
   accumulates unweighted PCM energy without saving audio. It rejects invalid
   data, interruptions, excessive clipping, changed sample rate and silent
   input, but it cannot verify source stability or the microphone response.
4. Repeat around 70 dB and 80 dB without changing the geometry.
5. Enter the reference `LZeq` and calculate each comparison offset:

   `offset dB = reference LZeq - OpenNoiseNet reading`

6. Record each suggested offset before starting the next comparison. If the
   offsets remain reasonably consistent across the three levels, use their
   mean in **Settings → Audio Calibration**. If they diverge materially,
   do not hide the problem with one offset; mark the device uncalibrated and
   investigate automatic gain control, clipping, or frequency response.
7. Repeat the three measurements after applying the offset. Store the date,
   phone model, OS version, app build, reference instrument, reference
   calibration date, source, geometry, readings, and residual errors.

Do not subtract an A-weighted broadband `LAeq` reference from the app's
unweighted estimate: the frequency responses differ. A newly assigned
calibration profile is metadata only; the current capture path does not apply
its correction. A nonzero manually entered offset is not evidence of a verified
calibration, and a valid offset could in principle be zero.

## Field acceptance

For the initial citizen-science pilot, define the accuracy tolerance before
collecting data and retain every residual rather than only a pass/fail label.
Regulatory or legal claims require an appropriate instrument, traceable
calibration, validated DSP, and a documented measurement method; the current
smartphone path does not meet that gate.

Source classification needs a separate validation matrix. Calibration of the
level does not prove that YAMNet correctly distinguishes conversation,
traffic, music, construction, or other sources through walls and across phone
models.
