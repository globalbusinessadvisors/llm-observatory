"""SQLAlchemy database models."""

from datetime import datetime
from typing import Optional
from uuid import uuid4

from sqlalchemy import (
    String, Text, Integer, Float, Boolean, DateTime,
    ForeignKey, Index, Enum as SQLEnum, JSON
)
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship
from sqlalchemy.dialects.postgresql import UUID
import enum


class Base(DeclarativeBase):
    """Base class for all database models."""
    pass


class ProviderEnum(str, enum.Enum):
    """LLM provider types."""
    OPENAI = "openai"
    ANTHROPIC = "anthropic"
    AZURE_OPENAI = "azure_openai"
    GOOGLE = "google"


class MessageRoleEnum(str, enum.Enum):
    """Message role types."""
    SYSTEM = "system"
    USER = "user"
    ASSISTANT = "assistant"
    FUNCTION = "function"


class FeedbackTypeEnum(str, enum.Enum):
    """Feedback types."""
    THUMBS_UP = "thumbs_up"
    THUMBS_DOWN = "thumbs_down"
    FLAG = "flag"


class Conversation(Base):
    """Conversation model."""
    __tablename__ = "conversations"

    id: Mapped[str] = mapped_column(
        UUID(as_uuid=False),
        primary_key=True,
        default=lambda: str(uuid4()),
    )
    user_id: Mapped[Optional[str]] = mapped_column(String(255), index=True)
    title: Mapped[Optional[str]] = mapped_column(String(500))
    metadata: Mapped[Optional[dict]] = mapped_column(JSON, default=dict)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=datetime.utcnow,
        index=True,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=datetime.utcnow,
        onupdate=datetime.utcnow,
    )

    # Relationships
    messages: Mapped[list["Message"]] = relationship(
        "Message",
        back_populates="conversation",
        cascade="all, delete-orphan",
        lazy="selectin",
    )
    feedback: Mapped[list["Feedback"]] = relationship(
        "Feedback",
        back_populates="conversation",
        cascade="all, delete-orphan",
    )

    # Indexes
    __table_args__ = (
        Index("idx_conversations_user_created", "user_id", "created_at"),
    )


class Message(Base):
    """Message model."""
    __tablename__ = "messages"

    id: Mapped[str] = mapped_column(
        UUID(as_uuid=False),
        primary_key=True,
        default=lambda: str(uuid4()),
    )
    conversation_id: Mapped[str] = mapped_column(
        UUID(as_uuid=False),
        ForeignKey("conversations.id", ondelete="CASCADE"),
        index=True,
    )
    role: Mapped[MessageRoleEnum] = mapped_column(SQLEnum(MessageRoleEnum))
    content: Mapped[str] = mapped_column(Text)

    # LLM metadata
    provider: Mapped[Optional[ProviderEnum]] = mapped_column(SQLEnum(ProviderEnum))
    model: Mapped[Optional[str]] = mapped_column(String(100))
    prompt_tokens: Mapped[Optional[int]] = mapped_column(Integer)
    completion_tokens: Mapped[Optional[int]] = mapped_column(Integer)
    total_tokens: Mapped[Optional[int]] = mapped_column(Integer)
    cost_usd: Mapped[Optional[float]] = mapped_column(Float)

    # Performance metrics
    latency_ms: Mapped[Optional[int]] = mapped_column(Integer)
    time_to_first_token_ms: Mapped[Optional[int]] = mapped_column(Integer)

    # Tracing
    trace_id: Mapped[Optional[str]] = mapped_column(String(255), index=True)
    span_id: Mapped[Optional[str]] = mapped_column(String(255))

    # Additional metadata
    metadata: Mapped[Optional[dict]] = mapped_column(JSON, default=dict)
    error: Mapped[Optional[str]] = mapped_column(Text)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=datetime.utcnow,
        index=True,
    )

    # Relationships
    conversation: Mapped["Conversation"] = relationship(
        "Conversation",
        back_populates="messages",
    )
    feedback: Mapped[list["Feedback"]] = relationship(
        "Feedback",
        back_populates="message",
        cascade="all, delete-orphan",
    )

    # Indexes
    __table_args__ = (
        Index("idx_messages_conversation_created", "conversation_id", "created_at"),
        Index("idx_messages_trace", "trace_id"),
    )


class Feedback(Base):
    """Feedback model for messages and conversations."""
    __tablename__ = "feedback"

    id: Mapped[str] = mapped_column(
        UUID(as_uuid=False),
        primary_key=True,
        default=lambda: str(uuid4()),
    )
    conversation_id: Mapped[str] = mapped_column(
        UUID(as_uuid=False),
        ForeignKey("conversations.id", ondelete="CASCADE"),
        index=True,
    )
    message_id: Mapped[Optional[str]] = mapped_column(
        UUID(as_uuid=False),
        ForeignKey("messages.id", ondelete="CASCADE"),
        index=True,
    )
    user_id: Mapped[Optional[str]] = mapped_column(String(255), index=True)

    feedback_type: Mapped[FeedbackTypeEnum] = mapped_column(SQLEnum(FeedbackTypeEnum))
    rating: Mapped[Optional[int]] = mapped_column(Integer)  # 1-5 scale
    comment: Mapped[Optional[str]] = mapped_column(Text)
    metadata: Mapped[Optional[dict]] = mapped_column(JSON, default=dict)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=datetime.utcnow,
        index=True,
    )

    # Relationships
    conversation: Mapped["Conversation"] = relationship(
        "Conversation",
        back_populates="feedback",
    )
    message: Mapped[Optional["Message"]] = relationship(
        "Message",
        back_populates="feedback",
    )

    # Indexes
    __table_args__ = (
        Index("idx_feedback_conversation_created", "conversation_id", "created_at"),
        Index("idx_feedback_message", "message_id"),
    )
