"""Pro domain foundation endpoints."""

from typing import Iterable, List, Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import require_user
from app.db.models.device import Device
from app.db.models.pro_domain import (
    CalibrationProfile,
    MembershipRole,
    Organization,
    OrganizationMembership,
    Policy,
    PolicyScope,
    Site,
    Zone,
)
from app.db.models.user import User
from app.db.session import get_session
from app.schemas.pro import (
    CalibrationProfileCreate,
    CalibrationProfileResponse,
    DeviceAssignmentResponse,
    DeviceAssignmentUpdate,
    OrganizationCreate,
    OrganizationResponse,
    PolicyCreate,
    PolicyResponse,
    SiteCreate,
    SiteDeviceResponse,
    SiteResponse,
    ZoneCreate,
    ZoneResponse,
)

organizations_router = APIRouter()
sites_router = APIRouter()
zones_router = APIRouter()
policies_router = APIRouter()
calibration_profiles_router = APIRouter()


def _slugify(value: str) -> str:
    return value.strip().lower().replace(" ", "-")


async def _get_membership(
    db: AsyncSession, organization_id: UUID, user_id: UUID
) -> Optional[OrganizationMembership]:
    result = await db.execute(
        select(OrganizationMembership).where(
            OrganizationMembership.organization_id == organization_id,
            OrganizationMembership.user_id == user_id,
        )
    )
    return result.scalar_one_or_none()


async def _require_org_membership(
    db: AsyncSession,
    organization_id: UUID,
    user: User,
    allowed_roles: Iterable[str] = (
        MembershipRole.OWNER.value,
        MembershipRole.ADMIN.value,
        MembershipRole.MEMBER.value,
    ),
) -> OrganizationMembership:
    membership = await _get_membership(db, organization_id, user.id)
    if not membership or membership.role not in set(allowed_roles):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Organization access denied",
        )
    return membership


async def _get_site_or_404(db: AsyncSession, site_id: UUID) -> Site:
    result = await db.execute(select(Site).where(Site.id == site_id))
    site = result.scalar_one_or_none()
    if not site:
        raise HTTPException(status_code=404, detail="Site not found")
    return site


async def _get_zone_or_404(db: AsyncSession, zone_id: UUID) -> Zone:
    result = await db.execute(select(Zone).where(Zone.id == zone_id))
    zone = result.scalar_one_or_none()
    if not zone:
        raise HTTPException(status_code=404, detail="Zone not found")
    return zone


async def _get_org_or_404(db: AsyncSession, organization_id: UUID) -> Organization:
    result = await db.execute(select(Organization).where(Organization.id == organization_id))
    organization = result.scalar_one_or_none()
    if not organization:
        raise HTTPException(status_code=404, detail="Organization not found")
    return organization


def _organization_response(organization: Organization, role: str) -> OrganizationResponse:
    return OrganizationResponse(
        id=organization.id,
        name=organization.name,
        slug=organization.slug,
        plan_tier=organization.plan_tier,
        status=organization.status,
        billing_state=organization.billing_state,
        created_by_id=organization.created_by_id,
        current_user_role=role,
        created_at=organization.created_at,
        updated_at=organization.updated_at,
    )


@organizations_router.post("/", response_model=OrganizationResponse, status_code=status.HTTP_201_CREATED)
async def create_organization(
    data: OrganizationCreate,
    db: AsyncSession = Depends(get_session),
    user: User = Depends(require_user),
):
    """Create an organization and grant owner membership to the current user."""

    slug = _slugify(data.slug)
    existing = await db.execute(select(Organization).where(Organization.slug == slug))
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=409, detail="Organization slug already exists")

    organization = Organization(
        name=data.name,
        slug=slug,
        plan_tier=data.plan_tier.value,
        created_by_id=user.id,
    )
    db.add(organization)
    await db.flush()

    membership = OrganizationMembership(
        organization_id=organization.id,
        user_id=user.id,
        role=MembershipRole.OWNER.value,
    )
    db.add(membership)
    await db.flush()
    await db.refresh(organization)
    return _organization_response(organization, membership.role)


@organizations_router.get("/", response_model=List[OrganizationResponse])
async def list_organizations(
    db: AsyncSession = Depends(get_session),
    user: User = Depends(require_user),
):
    """List organizations visible to the current user."""

    result = await db.execute(
        select(Organization, OrganizationMembership.role)
        .join(
            OrganizationMembership,
            OrganizationMembership.organization_id == Organization.id,
        )
        .where(OrganizationMembership.user_id == user.id)
        .order_by(Organization.created_at.desc())
    )
    return [_organization_response(org, role) for org, role in result.all()]


@organizations_router.get("/{organization_id}", response_model=OrganizationResponse)
async def get_organization(
    organization_id: UUID,
    db: AsyncSession = Depends(get_session),
    user: User = Depends(require_user),
):
    """Fetch one organization visible to the current user."""

    organization = await _get_org_or_404(db, organization_id)
    membership = await _require_org_membership(db, organization_id, user)
    return _organization_response(organization, membership.role)


@sites_router.post("/", response_model=SiteResponse, status_code=status.HTTP_201_CREATED)
async def create_site(
    data: SiteCreate,
    db: AsyncSession = Depends(get_session),
    user: User = Depends(require_user),
):
    """Create a site inside one organization."""

    await _get_org_or_404(db, data.organization_id)
    await _require_org_membership(
        db,
        data.organization_id,
        user,
        allowed_roles=(MembershipRole.OWNER.value, MembershipRole.ADMIN.value),
    )
    site = Site(**data.model_dump())
    db.add(site)
    await db.flush()
    await db.refresh(site)
    return SiteResponse.model_validate(site)


@sites_router.get("/", response_model=List[SiteResponse])
async def list_sites(
    organization_id: UUID,
    db: AsyncSession = Depends(get_session),
    user: User = Depends(require_user),
):
    """List sites for one organization."""

    await _require_org_membership(db, organization_id, user)
    result = await db.execute(
        select(Site)
        .where(Site.organization_id == organization_id)
        .order_by(Site.created_at.desc())
    )
    return [SiteResponse.model_validate(site) for site in result.scalars().all()]


@sites_router.get("/{site_id}", response_model=SiteResponse)
async def get_site(
    site_id: UUID,
    db: AsyncSession = Depends(get_session),
    user: User = Depends(require_user),
):
    """Fetch one site if the user belongs to the parent organization."""

    site = await _get_site_or_404(db, site_id)
    await _require_org_membership(db, site.organization_id, user)
    return SiteResponse.model_validate(site)


@sites_router.get("/{site_id}/devices", response_model=List[SiteDeviceResponse])
async def list_site_devices(
    site_id: UUID,
    db: AsyncSession = Depends(get_session),
    user: User = Depends(require_user),
):
    """List devices assigned to one site."""

    site = await _get_site_or_404(db, site_id)
    await _require_org_membership(db, site.organization_id, user)
    result = await db.execute(
        select(Device)
        .where(Device.site_id == site_id)
        .order_by(Device.updated_at.desc())
    )
    return [SiteDeviceResponse.model_validate(device) for device in result.scalars().all()]


@zones_router.post("/", response_model=ZoneResponse, status_code=status.HTTP_201_CREATED)
async def create_zone(
    data: ZoneCreate,
    db: AsyncSession = Depends(get_session),
    user: User = Depends(require_user),
):
    """Create a zone inside one site."""

    site = await _get_site_or_404(db, data.site_id)
    await _require_org_membership(
        db,
        site.organization_id,
        user,
        allowed_roles=(MembershipRole.OWNER.value, MembershipRole.ADMIN.value),
    )
    zone = Zone(**data.model_dump())
    db.add(zone)
    await db.flush()
    await db.refresh(zone)
    return ZoneResponse.model_validate(zone)


@zones_router.get("/", response_model=List[ZoneResponse])
async def list_zones(
    site_id: UUID,
    db: AsyncSession = Depends(get_session),
    user: User = Depends(require_user),
):
    """List zones for one site."""

    site = await _get_site_or_404(db, site_id)
    await _require_org_membership(db, site.organization_id, user)
    result = await db.execute(
        select(Zone).where(Zone.site_id == site_id).order_by(Zone.created_at.desc())
    )
    return [ZoneResponse.model_validate(zone) for zone in result.scalars().all()]


@zones_router.get("/{zone_id}", response_model=ZoneResponse)
async def get_zone(
    zone_id: UUID,
    db: AsyncSession = Depends(get_session),
    user: User = Depends(require_user),
):
    """Fetch one zone if the user belongs to the parent organization."""

    zone = await _get_zone_or_404(db, zone_id)
    site = await _get_site_or_404(db, zone.site_id)
    await _require_org_membership(db, site.organization_id, user)
    return ZoneResponse.model_validate(zone)


@policies_router.post("/", response_model=PolicyResponse, status_code=status.HTTP_201_CREATED)
async def create_policy(
    data: PolicyCreate,
    db: AsyncSession = Depends(get_session),
    user: User = Depends(require_user),
):
    """Create one organization-, site-, or zone-scoped policy."""

    organization_id: UUID
    if data.scope_type == PolicyScope.ORGANIZATION:
        organization = await _get_org_or_404(db, data.organization_id)
        organization_id = organization.id
    elif data.scope_type == PolicyScope.SITE:
        site = await _get_site_or_404(db, data.site_id)
        organization_id = site.organization_id
    else:
        zone = await _get_zone_or_404(db, data.zone_id)
        site = await _get_site_or_404(db, zone.site_id)
        organization_id = site.organization_id

    await _require_org_membership(
        db,
        organization_id,
        user,
        allowed_roles=(MembershipRole.OWNER.value, MembershipRole.ADMIN.value),
    )
    policy = Policy(
        **{
            **data.model_dump(),
            "scope_type": data.scope_type.value,
            "evidence_mode": data.evidence_mode.value,
        }
    )
    db.add(policy)
    await db.flush()
    await db.refresh(policy)
    return PolicyResponse.model_validate(policy)


@policies_router.get("/", response_model=List[PolicyResponse])
async def list_policies(
    organization_id: Optional[UUID] = None,
    site_id: Optional[UUID] = None,
    zone_id: Optional[UUID] = None,
    db: AsyncSession = Depends(get_session),
    user: User = Depends(require_user),
):
    """List policies for one scope."""

    if organization_id:
        await _require_org_membership(db, organization_id, user)
        stmt = select(Policy).where(Policy.organization_id == organization_id)
    elif site_id:
        site = await _get_site_or_404(db, site_id)
        await _require_org_membership(db, site.organization_id, user)
        stmt = select(Policy).where(Policy.site_id == site_id)
    elif zone_id:
        zone = await _get_zone_or_404(db, zone_id)
        site = await _get_site_or_404(db, zone.site_id)
        await _require_org_membership(db, site.organization_id, user)
        stmt = select(Policy).where(Policy.zone_id == zone_id)
    else:
        raise HTTPException(status_code=422, detail="One scope filter is required")

    result = await db.execute(stmt.order_by(Policy.created_at.desc()))
    return [PolicyResponse.model_validate(policy) for policy in result.scalars().all()]


@policies_router.get("/{policy_id}", response_model=PolicyResponse)
async def get_policy(
    policy_id: UUID,
    db: AsyncSession = Depends(get_session),
    user: User = Depends(require_user),
):
    """Fetch one policy if the user belongs to the owning organization."""

    result = await db.execute(select(Policy).where(Policy.id == policy_id))
    policy = result.scalar_one_or_none()
    if not policy:
        raise HTTPException(status_code=404, detail="Policy not found")

    if policy.organization_id:
        organization_id = policy.organization_id
    elif policy.site_id:
        site = await _get_site_or_404(db, policy.site_id)
        organization_id = site.organization_id
    else:
        zone = await _get_zone_or_404(db, policy.zone_id)
        site = await _get_site_or_404(db, zone.site_id)
        organization_id = site.organization_id

    await _require_org_membership(db, organization_id, user)
    return PolicyResponse.model_validate(policy)


@calibration_profiles_router.post("/", response_model=CalibrationProfileResponse, status_code=status.HTTP_201_CREATED)
async def create_calibration_profile(
    data: CalibrationProfileCreate,
    db: AsyncSession = Depends(get_session),
    user: User = Depends(require_user),
):
    """Create a calibration profile for one organization or site."""

    await _get_org_or_404(db, data.organization_id)
    await _require_org_membership(
        db,
        data.organization_id,
        user,
        allowed_roles=(MembershipRole.OWNER.value, MembershipRole.ADMIN.value),
    )
    if data.site_id:
        site = await _get_site_or_404(db, data.site_id)
        if site.organization_id != data.organization_id:
            raise HTTPException(status_code=400, detail="Site does not belong to organization")

    profile = CalibrationProfile(**data.model_dump())
    db.add(profile)
    await db.flush()
    await db.refresh(profile)
    return CalibrationProfileResponse.model_validate(profile)


@calibration_profiles_router.get("/", response_model=List[CalibrationProfileResponse])
async def list_calibration_profiles(
    organization_id: UUID,
    site_id: Optional[UUID] = None,
    db: AsyncSession = Depends(get_session),
    user: User = Depends(require_user),
):
    """List calibration profiles for one organization."""

    await _require_org_membership(db, organization_id, user)
    stmt = select(CalibrationProfile).where(
        CalibrationProfile.organization_id == organization_id
    )
    if site_id:
        stmt = stmt.where(CalibrationProfile.site_id == site_id)
    result = await db.execute(stmt.order_by(CalibrationProfile.created_at.desc()))
    return [
        CalibrationProfileResponse.model_validate(profile)
        for profile in result.scalars().all()
    ]


@calibration_profiles_router.get("/{profile_id}", response_model=CalibrationProfileResponse)
async def get_calibration_profile(
    profile_id: UUID,
    db: AsyncSession = Depends(get_session),
    user: User = Depends(require_user),
):
    """Fetch one calibration profile if the user belongs to the organization."""

    result = await db.execute(
        select(CalibrationProfile).where(CalibrationProfile.id == profile_id)
    )
    profile = result.scalar_one_or_none()
    if not profile:
        raise HTTPException(status_code=404, detail="Calibration profile not found")
    await _require_org_membership(db, profile.organization_id, user)
    return CalibrationProfileResponse.model_validate(profile)


@sites_router.put("/devices/{device_id}/assignment", response_model=DeviceAssignmentResponse)
async def assign_device_to_site(
    device_id: str,
    data: DeviceAssignmentUpdate,
    db: AsyncSession = Depends(get_session),
    user: User = Depends(require_user),
):
    """Assign one registered device into the Pro site and zone model."""

    site = await _get_site_or_404(db, data.site_id)
    await _require_org_membership(
        db,
        site.organization_id,
        user,
        allowed_roles=(MembershipRole.OWNER.value, MembershipRole.ADMIN.value),
    )

    zone = None
    if data.zone_id:
        zone = await _get_zone_or_404(db, data.zone_id)
        if zone.site_id != site.id:
            raise HTTPException(status_code=400, detail="Zone does not belong to site")

    if data.calibration_profile_id:
        result = await db.execute(
            select(CalibrationProfile).where(
                CalibrationProfile.id == data.calibration_profile_id
            )
        )
        profile = result.scalar_one_or_none()
        if not profile:
            raise HTTPException(status_code=404, detail="Calibration profile not found")
        if profile.organization_id != site.organization_id:
            raise HTTPException(
                status_code=400,
                detail="Calibration profile does not belong to the site organization",
            )
        if profile.site_id and profile.site_id != site.id:
            raise HTTPException(
                status_code=400,
                detail="Calibration profile belongs to a different site",
            )

    result = await db.execute(select(Device).where(Device.device_id == device_id))
    device = result.scalar_one_or_none()
    if not device:
        raise HTTPException(status_code=404, detail="Device not found")

    device.site_id = site.id
    device.zone_id = zone.id if zone else None
    device.calibration_profile_id = data.calibration_profile_id
    await db.flush()
    await db.refresh(device)

    return DeviceAssignmentResponse(
        device_id=device.device_id,
        site_id=device.site_id,
        zone_id=device.zone_id,
        calibration_profile_id=device.calibration_profile_id,
        updated_at=device.updated_at,
    )
