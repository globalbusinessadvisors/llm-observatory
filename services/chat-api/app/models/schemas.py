"""Pydantic schemas for API request/response models."""

from datetime import datetime
from typing import Optional, List, Dict, Any
from pydantic import BaseModel, Field, ConfigDict
from enum import Enum


class ProviderType(str, Enum):
    """LLM provider types."""
    OPENAI = "openai"
    ANTHROPIC = "anthropic"
    AZURE_OPENAI = "azure_openai"
    GOOGLE = "google"


class MessageRole(str, Enum):
    """Message role types."""
    SYSTEM = "system"
    USER = "user"
    ASSISTANT = "assistant"
    FUNCTION = "function"


class FeedbackType(str, Enum):
    """Feedback types."""
    THUMBS_UP = "thumbs_up"
    THUMBS_DOWN = "thumbs_down"
    FLAG = "flag"


# Conversation Schemas
class ConversationCreate(BaseModel):
    """Request schema for creating a conversation."""
    user_id: Optional[str] = None
    title: Optional[str] = None
    metadata: Optional[Dict[str, Any]] = Field(default_factory=dict)


class ConversationUpdate(BaseModel):
    """Request schema for updating a conversation."""
    title: Optional[str] = None
    metadata: Optional[Dict[str, Any]] = None


class ConversationResponse(BaseModel):
    """Response schema for a conversation."""
    model_config = ConfigDict(from_attributes=True)

    id: str
    user_id: Optional[str] = None
    title: Optional[str] = None
    metadata: Optional[Dict[str, Any]] = None
    created_at: datetime
    updated_at: datetime


class ConversationWithMessages(ConversationResponse):
    """Response schema for a conversation with messages."""
    messages: List["MessageResponse"] = Field(default_factory=list)


# Message Schemas
class MessageCreate(BaseModel):
    """Request schema for creating a message."""
    content: str = Field(..., min_length=1, max_length=100000)
    role: MessageRole = MessageRole.USER
    metadata: Optional[Dict[str, Any]] = Field(default_factory=dict)


class MessageResponse(BaseModel):
    """Response schema for a message."""
    model_config = ConfigDict(from_attributes=True)

    id: str
    conversation_id: str
    role: MessageRole
    content: str
    provider: Optional[ProviderType] = None
    model: Optional[str] = None
    prompt_tokens: Optional[int] = None
    completion_tokens: Optional[int] = None
    total_tokens: Optional[int] = None
    cost_usd: Optional[float] = None
    latency_ms: Optional[int] = None
    time_to_first_token_ms: Optional[int] = None
    trace_id: Optional[str] = None
    span_id: Optional[str] = None
    metadata: Optional[Dict[str, Any]] = None
    error: Optional[str] = None
    created_at: datetime


class MessageListResponse(BaseModel):
    """Response schema for a list of messages."""
    messages: List[MessageResponse]
    total: int
    limit: int
    offset: int


# Feedback Schemas
class FeedbackCreate(BaseModel):
    """Request schema for creating feedback."""
    message_id: Optional[str] = None
    user_id: Optional[str] = None
    feedback_type: FeedbackType
    rating: Optional[int] = Field(None, ge=1, le=5)
    comment: Optional[str] = Field(None, max_length=5000)
    metadata: Optional[Dict[str, Any]] = Field(default_factory=dict)


class FeedbackResponse(BaseModel):
    """Response schema for feedback."""
    model_config = ConfigDict(from_attributes=True)

    id: str
    conversation_id: str
    message_id: Optional[str] = None
    user_id: Optional[str] = None
    feedback_type: FeedbackType
    rating: Optional[int] = None
    comment: Optional[str] = None
    metadata: Optional[Dict[str, Any]] = None
    created_at: datetime


# Chat Schemas
class ChatRequest(BaseModel):
    """Request schema for chat completion."""
    message: str = Field(..., min_length=1, max_length=100000)
    provider: Optional[ProviderType] = None
    model: Optional[str] = None
    temperature: Optional[float] = Field(None, ge=0.0, le=2.0)
    max_tokens: Optional[int] = Field(None, ge=1, le=32000)
    stream: bool = False
    metadata: Optional[Dict[str, Any]] = Field(default_factory=dict)


class ChatResponse(BaseModel):
    """Response schema for chat completion."""
    message: MessageResponse
    conversation_id: str
    usage: Dict[str, int]
    cost_usd: float


class StreamChunk(BaseModel):
    """Response schema for streaming chunks."""
    content: str
    done: bool = False
    message_id: Optional[str] = None
    metadata: Optional[Dict[str, Any]] = None


# Error Schemas
class ErrorDetail(BaseModel):
    """Error detail schema."""
    code: str
    message: str
    field: Optional[str] = None


class ErrorResponse(BaseModel):
    """Error response schema."""
    error: ErrorDetail
    request_id: Optional[str] = None
    timestamp: datetime = Field(default_factory=datetime.utcnow)


# Health Check Schemas
class HealthResponse(BaseModel):
    """Health check response schema."""
    status: str
    service: str
    version: str
    timestamp: datetime = Field(default_factory=datetime.utcnow)


class ReadinessResponse(BaseModel):
    """Readiness check response schema."""
    status: str
    checks: Dict[str, str]
    timestamp: datetime = Field(default_factory=datetime.utcnow)
