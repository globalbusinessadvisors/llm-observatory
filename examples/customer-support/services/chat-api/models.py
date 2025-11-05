"""Data models for the chat API."""
from typing import Optional, List, Dict, Any, Literal
from pydantic import BaseModel, Field
from datetime import datetime


class Message(BaseModel):
    """A chat message."""
    role: Literal["user", "assistant", "system"]
    content: str
    metadata: Optional[Dict[str, Any]] = None


class ToolParameter(BaseModel):
    """Parameter definition for a tool."""
    type: str
    description: str
    enum: Optional[List[str]] = None
    required: bool = True


class Tool(BaseModel):
    """Tool definition for function calling."""
    name: str
    description: str
    parameters: Dict[str, ToolParameter]


class ChatRequest(BaseModel):
    """Request model for chat completion."""
    messages: List[Message]
    model: Optional[str] = None
    provider: Optional[str] = None
    stream: bool = False
    max_tokens: Optional[int] = None
    temperature: Optional[float] = 0.7
    tools: Optional[List[Tool]] = None
    user_id: Optional[str] = None
    session_id: Optional[str] = None
    experiment_id: Optional[str] = None


class UsageStats(BaseModel):
    """Token usage statistics."""
    prompt_tokens: int
    completion_tokens: int
    total_tokens: int
    estimated_cost: float


class ChatResponse(BaseModel):
    """Response model for chat completion."""
    message: Message
    usage: UsageStats
    provider: str
    model: str
    cached: bool = False
    tool_calls: Optional[List[Dict[str, Any]]] = None
    finish_reason: Optional[str] = None


class StreamChunk(BaseModel):
    """A chunk of streaming response."""
    delta: str
    finish_reason: Optional[str] = None
    usage: Optional[UsageStats] = None


class PIIDetection(BaseModel):
    """PII detection result."""
    detected: bool
    redacted_text: str
    pii_types: List[str] = Field(default_factory=list)
    locations: List[Dict[str, Any]] = Field(default_factory=list)


class ExperimentVariant(BaseModel):
    """A/B test variant configuration."""
    variant_id: str
    name: str
    provider: str
    model: str
    temperature: float = 0.7
    max_tokens: Optional[int] = None
    system_prompt: Optional[str] = None


class Experiment(BaseModel):
    """A/B test experiment configuration."""
    experiment_id: str
    name: str
    description: str
    variants: List[ExperimentVariant]
    traffic_split: Dict[str, float]  # variant_id -> percentage
    start_date: datetime
    end_date: Optional[datetime] = None
    is_active: bool = True


class ExperimentMetrics(BaseModel):
    """Metrics for an experiment variant."""
    variant_id: str
    total_requests: int = 0
    total_tokens: int = 0
    total_cost: float = 0.0
    avg_latency_ms: float = 0.0
    error_rate: float = 0.0
    user_satisfaction: Optional[float] = None


class CostOptimizationResult(BaseModel):
    """Result of cost optimization analysis."""
    original_tokens: int
    optimized_tokens: int
    savings_tokens: int
    savings_percent: float
    recommendations: List[str]
    action_taken: Optional[str] = None
