"""Audio snippet endpoints."""

from fastapi import APIRouter

router = APIRouter()


@router.post("/upload")
async def upload_snippet():
    """Upload audio snippet."""
    return {"message": "Upload snippet - TODO"}


@router.get("/{snippet_id}")
async def get_snippet(snippet_id: str):
    """Get audio snippet."""
    return {"message": f"Get snippet {snippet_id} - TODO"}


@router.delete("/{snippet_id}")
async def delete_snippet(snippet_id: str):
    """Delete audio snippet."""
    return {"message": f"Delete snippet {snippet_id} - TODO"}