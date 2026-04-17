"""Episode, case, and export workflows for the Pro operator product."""

from __future__ import annotations

import base64
import csv
import io
import json
from datetime import datetime, timezone
from typing import List, Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.endpoints.pro_domains import _get_org_or_404, _require_org_membership
from app.core.deps import require_user
from app.db.models.device import Device
from app.db.models.pro_domain import (
    Case,
    CaseEpisodeLink,
    Episode,
    EpisodeLifecycleState,
    EpisodeReviewState,
    ExportFormat,
    ExportJob,
)
from app.db.models.user import User
from app.db.session import get_session
from app.schemas.pro import (
    CaseCreate,
    CaseResponse,
    EpisodeListResponse,
    EpisodeResponse,
    EpisodeReviewRequest,
    ExportCreate,
    ExportResponse,
)

episodes_router = APIRouter()
cases_router = APIRouter()
exports_router = APIRouter()


async def _get_episode_or_404(db: AsyncSession, episode_id: UUID) -> Episode:
    result = await db.execute(select(Episode).where(Episode.id == episode_id))
    episode = result.scalar_one_or_none()
    if not episode:
        raise HTTPException(status_code=404, detail="Episode not found")
    return episode


async def _get_case_or_404(db: AsyncSession, case_id: UUID) -> Case:
    result = await db.execute(select(Case).where(Case.id == case_id))
    case = result.scalar_one_or_none()
    if not case:
        raise HTTPException(status_code=404, detail="Case not found")
    return case


async def _get_export_or_404(db: AsyncSession, export_id: UUID) -> ExportJob:
    result = await db.execute(select(ExportJob).where(ExportJob.id == export_id))
    export_job = result.scalar_one_or_none()
    if not export_job:
        raise HTTPException(status_code=404, detail="Export not found")
    return export_job


async def _device_public_id_map(
    db: AsyncSession, device_ids: List[UUID]
) -> dict[UUID, str]:
    if not device_ids:
        return {}
    result = await db.execute(select(Device).where(Device.id.in_(device_ids)))
    return {device.id: device.device_id for device in result.scalars().all()}


def _serialize_episode(episode: Episode, device_public_id: str) -> EpisodeResponse:
    return EpisodeResponse(
        id=episode.id,
        organization_id=episode.organization_id,
        site_id=episode.site_id,
        zone_id=episode.zone_id,
        device_id=episode.device_id,
        device_public_id=device_public_id,
        policy_id=episode.policy_id,
        primary_class=episode.primary_class,
        effective_label=episode.review_label or episode.primary_class,
        class_family=episode.class_family,
        review_label=episode.review_label,
        classification_confidence=episode.classification_confidence,
        severity=episode.severity,
        effective_severity=episode.reviewed_severity or episode.severity,
        reviewed_severity=episode.reviewed_severity,
        nuisance_score=episode.nuisance_score,
        quiet_hours_triggered=episode.quiet_hours_triggered,
        evidence_mode=episode.evidence_mode,
        review_state=episode.review_state,
        lifecycle_state=episode.lifecycle_state,
        started_at=episode.started_at,
        ended_at=episode.ended_at,
        event_count=episode.event_count,
        review_notes=episode.review_notes,
        model_bundle_id=episode.model_bundle_id,
        reviewed_by_id=episode.reviewed_by_id,
        reviewed_at=episode.reviewed_at,
        exported_at=episode.exported_at,
        created_at=episode.created_at,
        updated_at=episode.updated_at,
    )


async def _serialize_case(db: AsyncSession, case: Case) -> CaseResponse:
    links_result = await db.execute(
        select(CaseEpisodeLink.episode_id).where(CaseEpisodeLink.case_id == case.id)
    )
    episode_ids = [episode_id for episode_id in links_result.scalars().all()]
    return CaseResponse(
        id=case.id,
        organization_id=case.organization_id,
        site_id=case.site_id,
        zone_id=case.zone_id,
        opened_by_id=case.opened_by_id,
        status=case.status,
        title=case.title,
        summary=case.summary,
        opened_at=case.opened_at,
        closed_at=case.closed_at,
        episode_ids=episode_ids,
        episode_count=len(episode_ids),
        created_at=case.created_at,
        updated_at=case.updated_at,
    )


def _serialize_export(export_job: ExportJob) -> ExportResponse:
    preview = None
    if export_job.output_text:
        if export_job.output_encoding == "base64":
            preview = "Binary export ready for download"
        else:
            preview = export_job.output_text[:400]

    return ExportResponse(
        id=export_job.id,
        case_id=export_job.case_id,
        created_by_id=export_job.created_by_id,
        format=export_job.format,
        status=export_job.status,
        file_name=export_job.file_name,
        content_type=export_job.content_type,
        output_encoding=export_job.output_encoding,
        preview=preview,
        exported_at=export_job.exported_at,
        created_at=export_job.created_at,
        updated_at=export_job.updated_at,
    )


@episodes_router.get("/", response_model=EpisodeListResponse)
async def list_episodes(
    organization_id: UUID,
    site_id: Optional[UUID] = Query(None),
    zone_id: Optional[UUID] = Query(None),
    review_state: Optional[str] = Query(None),
    severity: Optional[str] = Query(None),
    limit: int = Query(default=100, ge=1, le=500),
    db: AsyncSession = Depends(get_session),
    user: User = Depends(require_user),
):
    await _get_org_or_404(db, organization_id)
    await _require_org_membership(db, organization_id, user)

    stmt = select(Episode).where(Episode.organization_id == organization_id)
    if site_id:
        stmt = stmt.where(Episode.site_id == site_id)
    if zone_id:
        stmt = stmt.where(Episode.zone_id == zone_id)
    if review_state:
        stmt = stmt.where(Episode.review_state == review_state)
    if severity:
        stmt = stmt.where(
            (Episode.reviewed_severity == severity) | (Episode.severity == severity)
        )

    stmt = stmt.order_by(Episode.started_at.desc()).limit(limit)
    result = await db.execute(stmt)
    episodes = result.scalars().all()
    device_map = await _device_public_id_map(db, [episode.device_id for episode in episodes])
    return EpisodeListResponse(
        episodes=[
            _serialize_episode(episode, device_map.get(episode.device_id, str(episode.device_id)))
            for episode in episodes
        ],
        total=len(episodes),
    )


@episodes_router.get("/{episode_id}", response_model=EpisodeResponse)
async def get_episode(
    episode_id: UUID,
    db: AsyncSession = Depends(get_session),
    user: User = Depends(require_user),
):
    episode = await _get_episode_or_404(db, episode_id)
    await _require_org_membership(db, episode.organization_id, user)
    device_map = await _device_public_id_map(db, [episode.device_id])
    return _serialize_episode(episode, device_map.get(episode.device_id, str(episode.device_id)))


@episodes_router.post("/{episode_id}/review", response_model=EpisodeResponse)
async def review_episode(
    episode_id: UUID,
    payload: EpisodeReviewRequest,
    db: AsyncSession = Depends(get_session),
    user: User = Depends(require_user),
):
    episode = await _get_episode_or_404(db, episode_id)
    await _require_org_membership(db, episode.organization_id, user)

    episode.review_state = payload.review_state.value
    if payload.review_label:
        episode.review_label = payload.review_label.strip().lower().replace(" ", "_")
    if payload.severity:
        episode.reviewed_severity = payload.severity.value
    if payload.notes:
        episode.review_notes = payload.notes
    episode.reviewed_by_id = user.id
    episode.reviewed_at = datetime.now(timezone.utc)
    if payload.review_state in {
        EpisodeReviewState.CONFIRMED,
        EpisodeReviewState.OVERRIDDEN,
    }:
        episode.lifecycle_state = EpisodeLifecycleState.CLOSED.value

    await db.flush()
    await db.refresh(episode)
    device_map = await _device_public_id_map(db, [episode.device_id])
    return _serialize_episode(episode, device_map.get(episode.device_id, str(episode.device_id)))


@cases_router.post("/", response_model=CaseResponse, status_code=status.HTTP_201_CREATED)
async def create_case(
    payload: CaseCreate,
    db: AsyncSession = Depends(get_session),
    user: User = Depends(require_user),
):
    await _get_org_or_404(db, payload.organization_id)
    await _require_org_membership(db, payload.organization_id, user)

    episodes_result = await db.execute(
        select(Episode).where(Episode.id.in_(payload.episode_ids))
    )
    episodes = episodes_result.scalars().all()
    if len(episodes) != len(payload.episode_ids):
        raise HTTPException(status_code=404, detail="One or more episodes not found")

    for episode in episodes:
        if episode.organization_id != payload.organization_id or episode.site_id != payload.site_id:
            raise HTTPException(
                status_code=400,
                detail="All episodes must belong to the same organization and site",
            )

    new_case = Case(
        organization_id=payload.organization_id,
        site_id=payload.site_id,
        zone_id=payload.zone_id,
        opened_by_id=user.id,
        title=payload.title,
        summary=payload.summary,
        opened_at=datetime.now(timezone.utc),
    )
    db.add(new_case)
    await db.flush()

    for episode in episodes:
        db.add(CaseEpisodeLink(case_id=new_case.id, episode_id=episode.id))

    await db.flush()
    return await _serialize_case(db, new_case)


@cases_router.get("/", response_model=List[CaseResponse])
async def list_cases(
    organization_id: UUID,
    site_id: Optional[UUID] = Query(None),
    status: Optional[str] = Query(None),
    db: AsyncSession = Depends(get_session),
    user: User = Depends(require_user),
):
    await _get_org_or_404(db, organization_id)
    await _require_org_membership(db, organization_id, user)

    stmt = select(Case).where(Case.organization_id == organization_id)
    if site_id:
        stmt = stmt.where(Case.site_id == site_id)
    if status:
        stmt = stmt.where(Case.status == status)
    stmt = stmt.order_by(Case.opened_at.desc())
    result = await db.execute(stmt)
    cases = result.scalars().all()
    return [await _serialize_case(db, case) for case in cases]


@cases_router.get("/{case_id}", response_model=CaseResponse)
async def get_case(
    case_id: UUID,
    db: AsyncSession = Depends(get_session),
    user: User = Depends(require_user),
):
    case = await _get_case_or_404(db, case_id)
    await _require_org_membership(db, case.organization_id, user)
    return await _serialize_case(db, case)


@exports_router.post("/", response_model=ExportResponse, status_code=status.HTTP_201_CREATED)
async def create_export(
    payload: ExportCreate,
    db: AsyncSession = Depends(get_session),
    user: User = Depends(require_user),
):
    case = await _get_case_or_404(db, payload.case_id)
    await _require_org_membership(db, case.organization_id, user)

    episodes_result = await db.execute(
        select(Episode)
        .join(CaseEpisodeLink, CaseEpisodeLink.episode_id == Episode.id)
        .where(CaseEpisodeLink.case_id == case.id)
        .order_by(Episode.started_at.asc())
    )
    episodes = episodes_result.scalars().all()
    if not episodes:
        raise HTTPException(status_code=400, detail="Case has no episodes to export")

    device_map = await _device_public_id_map(db, [episode.device_id for episode in episodes])
    export_body, content_type, encoding = _render_export(
        export_format=payload.format.value,
        case=case,
        episodes=episodes,
        device_map=device_map,
    )

    now = datetime.now(timezone.utc)
    export_job = ExportJob(
        case_id=case.id,
        created_by_id=user.id,
        format=payload.format.value,
        status="ready",
        file_name=f"{case.title.lower().replace(' ', '-')}.{payload.format.value}",
        content_type=content_type,
        output_text=export_body,
        output_encoding=encoding,
        exported_at=now,
    )
    db.add(export_job)

    for episode in episodes:
        episode.exported_at = now
        episode.lifecycle_state = EpisodeLifecycleState.EXPORTED.value

    await db.flush()
    return _serialize_export(export_job)


@exports_router.get("/", response_model=List[ExportResponse])
async def list_exports(
    organization_id: UUID,
    case_id: Optional[UUID] = Query(None),
    db: AsyncSession = Depends(get_session),
    user: User = Depends(require_user),
):
    await _get_org_or_404(db, organization_id)
    await _require_org_membership(db, organization_id, user)

    stmt = select(ExportJob).join(Case, Case.id == ExportJob.case_id).where(
        Case.organization_id == organization_id
    )
    if case_id:
        stmt = stmt.where(ExportJob.case_id == case_id)
    stmt = stmt.order_by(ExportJob.created_at.desc())
    result = await db.execute(stmt)
    return [_serialize_export(export_job) for export_job in result.scalars().all()]


@exports_router.get("/{export_id}", response_model=ExportResponse)
async def get_export(
    export_id: UUID,
    db: AsyncSession = Depends(get_session),
    user: User = Depends(require_user),
):
    export_job = await _get_export_or_404(db, export_id)
    case = await _get_case_or_404(db, export_job.case_id)
    await _require_org_membership(db, case.organization_id, user)
    return _serialize_export(export_job)


@exports_router.get("/{export_id}/content")
async def get_export_content(
    export_id: UUID,
    db: AsyncSession = Depends(get_session),
    user: User = Depends(require_user),
):
    export_job = await _get_export_or_404(db, export_id)
    case = await _get_case_or_404(db, export_job.case_id)
    await _require_org_membership(db, case.organization_id, user)

    if not export_job.output_text:
        raise HTTPException(status_code=404, detail="Export content not available")

    if export_job.output_encoding == "base64":
        content = base64.b64decode(export_job.output_text.encode("utf-8"))
    else:
        content = export_job.output_text.encode("utf-8")

    return Response(
        content=content,
        media_type=export_job.content_type,
        headers={
            "Content-Disposition": f'attachment; filename="{export_job.file_name}"'
        },
    )


def _render_export(*, export_format: str, case: Case, episodes: List[Episode], device_map: dict[UUID, str]):
    if export_format == ExportFormat.JSON.value:
        body = json.dumps(
            {
                "case": {
                    "id": str(case.id),
                    "title": case.title,
                    "summary": case.summary,
                    "status": case.status,
                    "opened_at": case.opened_at.isoformat(),
                },
                "episodes": [
                    {
                        "id": str(episode.id),
                        "device_id": device_map.get(episode.device_id, str(episode.device_id)),
                        "primary_class": episode.primary_class,
                        "effective_label": episode.review_label or episode.primary_class,
                        "severity": episode.reviewed_severity or episode.severity,
                        "nuisance_score": episode.nuisance_score,
                        "review_state": episode.review_state,
                        "started_at": episode.started_at.isoformat(),
                        "ended_at": episode.ended_at.isoformat(),
                        "event_count": episode.event_count,
                        "evidence_mode": episode.evidence_mode,
                        "review_notes": episode.review_notes,
                    }
                    for episode in episodes
                ],
            },
            indent=2,
        )
        return body, "application/json", "utf-8"

    if export_format == ExportFormat.CSV.value:
        buffer = io.StringIO()
        writer = csv.writer(buffer)
        writer.writerow(
            [
                "episode_id",
                "device_id",
                "primary_class",
                "effective_label",
                "severity",
                "nuisance_score",
                "review_state",
                "started_at",
                "ended_at",
                "event_count",
                "evidence_mode",
            ]
        )
        for episode in episodes:
            writer.writerow(
                [
                    str(episode.id),
                    device_map.get(episode.device_id, str(episode.device_id)),
                    episode.primary_class,
                    episode.review_label or episode.primary_class,
                    episode.reviewed_severity or episode.severity,
                    episode.nuisance_score,
                    episode.review_state,
                    episode.started_at.isoformat(),
                    episode.ended_at.isoformat(),
                    episode.event_count,
                    episode.evidence_mode,
                ]
            )
        return buffer.getvalue(), "text/csv", "utf-8"

    lines = [
        f"OpenNoiseNet Pro Case Export",
        f"Case: {case.title}",
        f"Status: {case.status}",
        f"Opened at: {case.opened_at.isoformat()}",
        "",
    ]
    for episode in episodes:
        lines.extend(
            [
                f"Episode {episode.id}",
                f"Device: {device_map.get(episode.device_id, str(episode.device_id))}",
                f"Label: {episode.review_label or episode.primary_class}",
                f"Severity: {episode.reviewed_severity or episode.severity}",
                f"Nuisance Score: {episode.nuisance_score}",
                f"Window: {episode.started_at.isoformat()} -> {episode.ended_at.isoformat()}",
                f"Review State: {episode.review_state}",
                "",
            ]
        )
    pdf_bytes = _render_minimal_pdf(lines)
    return base64.b64encode(pdf_bytes).decode("utf-8"), "application/pdf", "base64"


def _render_minimal_pdf(lines: List[str]) -> bytes:
    escaped_lines = [
        line.replace("\\", "\\\\").replace("(", "\\(").replace(")", "\\)")
        for line in lines
    ]
    text_commands = ["BT", "/F1 12 Tf", "50 780 Td"]
    for index, line in enumerate(escaped_lines):
        if index == 0:
            text_commands.append(f"({line}) Tj")
        else:
            text_commands.append("0 -16 Td")
            text_commands.append(f"({line}) Tj")
    text_commands.append("ET")
    stream = "\n".join(text_commands).encode("utf-8")

    objects = []
    objects.append(b"1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj\n")
    objects.append(b"2 0 obj << /Type /Pages /Kids [3 0 R] /Count 1 >> endobj\n")
    objects.append(
        b"3 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >> endobj\n"
    )
    objects.append(
        f"4 0 obj << /Length {len(stream)} >> stream\n".encode("utf-8")
        + stream
        + b"\nendstream endobj\n"
    )
    objects.append(b"5 0 obj << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >> endobj\n")

    output = bytearray(b"%PDF-1.4\n")
    offsets = [0]
    for obj in objects:
        offsets.append(len(output))
        output.extend(obj)

    xref_offset = len(output)
    output.extend(f"xref\n0 {len(offsets)}\n".encode("utf-8"))
    output.extend(b"0000000000 65535 f \n")
    for offset in offsets[1:]:
        output.extend(f"{offset:010d} 00000 n \n".encode("utf-8"))
    output.extend(
        f"trailer << /Size {len(offsets)} /Root 1 0 R >>\nstartxref\n{xref_offset}\n%%EOF".encode(
            "utf-8"
        )
    )
    return bytes(output)
