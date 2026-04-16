"""Audio snippet endpoints.

Audio snippet upload is intentionally held back from the current MVP release.
"""

from fastapi import APIRouter, HTTPException, status

router = APIRouter()


@router.post("/upload")
async def upload_snippet():
    """Audio snippets are not available in the current MVP."""
    raise HTTPException(
        status_code=status.HTTP_501_NOT_IMPLEMENTED,
        detail="Audio snippet APIs are not part of the current MVP release.",
    )


@router.get("/{snippet_id}")
async def get_snippet(_snippet_id: str):
    """Audio snippets are not available in the current MVP."""
    raise HTTPException(
        status_code=status.HTTP_501_NOT_IMPLEMENTED,
        detail="Audio snippet APIs are not part of the current MVP release.",
    )


@router.delete("/{snippet_id}")
async def delete_snippet(_snippet_id: str):
    """Audio snippets are not available in the current MVP."""
    raise HTTPException(
        status_code=status.HTTP_501_NOT_IMPLEMENTED,
        detail="Audio snippet APIs are not part of the current MVP release.",
    )
