"""Audio snippet model for optional audio storage."""

import uuid
from datetime import datetime
from typing import Optional

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, String
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class AudioSnippet(Base):
    """Audio snippet model for optional encrypted audio storage."""
    
    __tablename__ = "audio_snippets"
    
    # Event relationship
    event_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("events.id", ondelete="CASCADE"), nullable=False
    )
    
    # Audio format information
    codec: Mapped[str] = mapped_column(String(20), nullable=False)  # 'opus', 'wav', 'flac', 'mp3'
    duration_seconds: Mapped[int] = mapped_column(nullable=False)
    sample_rate: Mapped[int] = mapped_column(nullable=False)
    file_size_bytes: Mapped[Optional[int]] = mapped_column()
    
    # Storage information
    file_path: Mapped[Optional[str]] = mapped_column(String(500))
    
    # Security information
    encryption_key_hash: Mapped[Optional[str]] = mapped_column(String(64))  # Hash of encryption key
    checksum: Mapped[Optional[str]] = mapped_column(String(64))  # File integrity check
    
    # Lifecycle management
    uploaded_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, index=True
    )
    expires_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, index=True
    )
    is_processed: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    
    # Relationships
    event = relationship("Event", back_populates="audio_snippets")
    
    def __repr__(self) -> str:
        return f"<AudioSnippet(id={self.id}, event_id={self.event_id}, codec={self.codec})>"