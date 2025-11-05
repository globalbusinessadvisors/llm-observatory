"""Main FastAPI application for chat API with advanced features."""
import logging
import time
import json
from typing import Optional
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import StreamingResponse
from fastapi.middleware.cors import CORSMiddleware
import uvicorn

from models import ChatRequest, ChatResponse, StreamChunk
from provider_manager import ProviderManager
from cache_manager import CacheManager
from pii_detector import PIIDetector
from cost_optimizer import CostOptimizer
from ab_testing import ABTestingManager
from tools_framework import ToolRegistry
from config import settings


# Configure logging
logging.basicConfig(
    level=getattr(logging, settings.log_level),
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger(__name__)


# Global instances
provider_manager: Optional[ProviderManager] = None
cache_manager: Optional[CacheManager] = None
pii_detector: Optional[PIIDetector] = None
cost_optimizer: Optional[CostOptimizer] = None
ab_testing_manager: Optional[ABTestingManager] = None
tool_registry: Optional[ToolRegistry] = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan manager."""
    global provider_manager, cache_manager, pii_detector, cost_optimizer
    global ab_testing_manager, tool_registry

    # Startup
    logger.info("Initializing chat API...")

    try:
        provider_manager = ProviderManager()
        cache_manager = CacheManager()
        pii_detector = PIIDetector()
        cost_optimizer = CostOptimizer()
        ab_testing_manager = ABTestingManager()
        tool_registry = ToolRegistry()

        logger.info("All managers initialized successfully")

    except Exception as e:
        logger.error(f"Failed to initialize application: {e}")
        raise

    yield

    # Shutdown
    logger.info("Shutting down chat API...")


app = FastAPI(
    title="Advanced Chat API",
    description="Production-ready chat API with multi-provider support, streaming, A/B testing, and more",
    version="1.0.0",
    lifespan=lifespan,
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure appropriately for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.middleware("http")
async def log_requests(request: Request, call_next):
    """Log all requests."""
    start_time = time.time()

    response = await call_next(request)

    duration = time.time() - start_time
    logger.info(
        f"{request.method} {request.url.path} - "
        f"Status: {response.status_code} - "
        f"Duration: {duration:.3f}s"
    )

    return response


@app.get("/")
async def root():
    """Root endpoint."""
    return {
        "service": "Advanced Chat API",
        "version": "1.0.0",
        "status": "healthy",
    }


@app.get("/health")
async def health():
    """Health check endpoint."""
    return {
        "status": "healthy",
        "providers": len(provider_manager.providers),
        "cache_enabled": cache_manager.enabled,
        "pii_detection_enabled": settings.enable_pii_detection,
        "ab_testing_enabled": settings.enable_ab_testing,
    }


@app.get("/providers")
async def list_providers():
    """List available providers."""
    return {
        "providers": provider_manager.get_available_providers(),
        "default_provider": settings.default_provider,
        "fallback_enabled": settings.enable_fallback,
    }


@app.get("/tools")
async def list_tools():
    """List available tools."""
    tools = tool_registry.get_all_tools()
    return {
        "tools": [
            {
                "name": tool.name,
                "description": tool.description,
                "parameters": {
                    name: {
                        "type": param.type,
                        "description": param.description,
                        "required": param.required,
                        "enum": param.enum,
                    }
                    for name, param in tool.parameters.items()
                },
            }
            for tool in tools
        ]
    }


@app.post("/chat/completions", response_model=ChatResponse)
async def create_chat_completion(request: ChatRequest):
    """Create a chat completion.

    Supports:
    - Multi-provider with automatic fallback
    - PII detection and redaction
    - Prompt caching
    - Cost optimization
    - A/B testing
    - Function calling
    """
    start_time = time.time()

    try:
        # PII detection and redaction
        if settings.enable_pii_detection:
            for message in request.messages:
                pii_result = pii_detector.detect_and_redact(message.content)
                if pii_result.detected:
                    logger.warning(
                        f"PII detected: {pii_result.pii_types}. "
                        "Content has been redacted."
                    )
                    message.content = pii_result.redacted_text

        # A/B testing variant assignment
        variant = None
        if settings.enable_ab_testing and request.experiment_id and request.user_id:
            variant = ab_testing_manager.assign_variant(
                request.experiment_id, request.user_id
            )
            if variant:
                logger.info(
                    f"User {request.user_id} assigned to variant {variant.variant_id}"
                )
                # Override provider/model with variant configuration
                request.provider = variant.provider
                request.model = variant.model
                request.temperature = variant.temperature
                if variant.max_tokens:
                    request.max_tokens = variant.max_tokens

                # Add system message if specified
                if variant.system_prompt:
                    from models import Message
                    system_msg = Message(role="system", content=variant.system_prompt)
                    request.messages.insert(0, system_msg)

        # Cost optimization analysis
        provider = provider_manager.get_provider(request.provider)
        optimization_result = cost_optimizer.analyze_context(
            request.messages, lambda text: provider.count_tokens(text, request.model or "")
        )

        logger.info(
            f"Context analysis: {optimization_result.original_tokens} tokens, "
            f"Recommendations: {len(optimization_result.recommendations)}"
        )

        # Check cache
        cached_response = None
        if settings.enable_prompt_caching and not request.stream:
            cached_response = cache_manager.get(
                request.messages,
                request.model or "",
                request.temperature,
                request.max_tokens,
            )

        if cached_response:
            logger.info("Returning cached response")
            return cached_response

        # Prepare tools if requested
        tools = None
        if request.tools:
            tools = request.tools

        # Complete with fallback
        response = await provider_manager.complete_with_fallback(
            messages=request.messages,
            model=request.model,
            provider_name=request.provider,
            max_tokens=request.max_tokens,
            temperature=request.temperature,
            tools=tools,
        )

        # Cache response
        if settings.enable_prompt_caching:
            cache_manager.set(
                request.messages,
                response.model,
                request.temperature,
                request.max_tokens,
                response,
            )

        # Handle tool calls if present
        if response.tool_calls:
            logger.info(f"Executing {len(response.tool_calls)} tool calls")
            tool_results = await tool_registry.execute_tool_calls(response.tool_calls)

            # Add tool results to response metadata
            response.message.metadata = {"tool_results": tool_results}

        # Record A/B testing metrics
        if variant and request.experiment_id:
            latency_ms = (time.time() - start_time) * 1000
            ab_testing_manager.record_metrics(
                experiment_id=request.experiment_id,
                variant_id=variant.variant_id,
                tokens=response.usage.total_tokens,
                cost=response.usage.estimated_cost,
                latency_ms=latency_ms,
                error=False,
            )

        return response

    except Exception as e:
        logger.error(f"Chat completion error: {e}", exc_info=True)

        # Record error in A/B testing if applicable
        if variant and request.experiment_id:
            latency_ms = (time.time() - start_time) * 1000
            ab_testing_manager.record_metrics(
                experiment_id=request.experiment_id,
                variant_id=variant.variant_id,
                tokens=0,
                cost=0,
                latency_ms=latency_ms,
                error=True,
            )

        raise HTTPException(status_code=500, detail=str(e))


@app.post("/chat/completions/stream")
async def create_chat_completion_stream(request: ChatRequest):
    """Create a streaming chat completion.

    Returns Server-Sent Events (SSE) stream.
    """
    if not request.stream:
        request.stream = True

    async def event_generator():
        """Generate SSE events."""
        start_time = time.time()
        total_tokens = 0
        error_occurred = False
        variant = None

        try:
            # PII detection
            if settings.enable_pii_detection:
                for message in request.messages:
                    pii_result = pii_detector.detect_and_redact(message.content)
                    if pii_result.detected:
                        message.content = pii_result.redacted_text

            # A/B testing
            if settings.enable_ab_testing and request.experiment_id and request.user_id:
                variant = ab_testing_manager.assign_variant(
                    request.experiment_id, request.user_id
                )
                if variant:
                    request.provider = variant.provider
                    request.model = variant.model
                    request.temperature = variant.temperature

            # Stream completion
            async for chunk in provider_manager.stream_with_fallback(
                messages=request.messages,
                model=request.model,
                provider_name=request.provider,
                max_tokens=request.max_tokens,
                temperature=request.temperature,
                tools=request.tools,
            ):
                # Send chunk as SSE
                chunk_data = chunk.model_dump()
                yield f"data: {json.dumps(chunk_data)}\n\n"

                if chunk.usage:
                    total_tokens = chunk.usage.total_tokens

        except Exception as e:
            error_occurred = True
            logger.error(f"Streaming error: {e}", exc_info=True)
            error_data = {"error": str(e), "finish_reason": "error"}
            yield f"data: {json.dumps(error_data)}\n\n"

        finally:
            # Record metrics
            if variant and request.experiment_id:
                latency_ms = (time.time() - start_time) * 1000
                ab_testing_manager.record_metrics(
                    experiment_id=request.experiment_id,
                    variant_id=variant.variant_id,
                    tokens=total_tokens,
                    cost=0,  # Cost calculated in final chunk
                    latency_ms=latency_ms,
                    error=error_occurred,
                )

            # Send done event
            yield "data: [DONE]\n\n"

    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",
        },
    )


@app.post("/experiments")
async def create_experiment(experiment: dict):
    """Create a new A/B testing experiment."""
    from models import Experiment, ExperimentVariant
    from datetime import datetime

    try:
        # Parse experiment data
        variants = [ExperimentVariant(**v) for v in experiment["variants"]]
        exp = Experiment(
            experiment_id=experiment["experiment_id"],
            name=experiment["name"],
            description=experiment["description"],
            variants=variants,
            traffic_split=experiment["traffic_split"],
            start_date=datetime.fromisoformat(experiment["start_date"]),
            end_date=(
                datetime.fromisoformat(experiment["end_date"])
                if experiment.get("end_date")
                else None
            ),
            is_active=experiment.get("is_active", True),
        )

        success = ab_testing_manager.create_experiment(exp)

        if success:
            return {"success": True, "experiment_id": exp.experiment_id}
        else:
            raise HTTPException(status_code=400, detail="Failed to create experiment")

    except Exception as e:
        logger.error(f"Error creating experiment: {e}")
        raise HTTPException(status_code=400, detail=str(e))


@app.get("/experiments")
async def list_experiments():
    """List all experiments."""
    return {"experiments": ab_testing_manager.list_experiments()}


@app.get("/experiments/{experiment_id}")
async def get_experiment_results(experiment_id: str):
    """Get results for an experiment."""
    results = ab_testing_manager.get_experiment_results(experiment_id)

    if "error" in results:
        raise HTTPException(status_code=404, detail=results["error"])

    return results


@app.post("/experiments/{experiment_id}/stop")
async def stop_experiment(experiment_id: str):
    """Stop an experiment."""
    ab_testing_manager.stop_experiment(experiment_id)
    return {"success": True, "experiment_id": experiment_id}


@app.get("/experiments/{experiment_id}/winner")
async def get_experiment_winner(experiment_id: str):
    """Get winning variant for an experiment."""
    winner = ab_testing_manager.get_winner(experiment_id)

    if winner is None:
        raise HTTPException(
            status_code=404, detail="No winner determined or experiment not found"
        )

    return {"experiment_id": experiment_id, "winner_variant_id": winner}


@app.get("/cache/stats")
async def get_cache_stats():
    """Get cache statistics."""
    return cache_manager.get_stats()


@app.post("/cache/clear")
async def clear_cache():
    """Clear all cached responses."""
    success = cache_manager.clear_all()
    return {"success": success}


@app.post("/pii/detect")
async def detect_pii(data: dict):
    """Detect PII in text."""
    text = data.get("text", "")
    result = pii_detector.detect_and_redact(text, audit=False)

    return {
        "detected": result.detected,
        "redacted_text": result.redacted_text,
        "pii_types": result.pii_types,
        "locations": result.locations,
    }


@app.post("/cost/analyze")
async def analyze_cost(data: dict):
    """Analyze cost for given messages."""
    from models import Message

    messages = [Message(**m) for m in data.get("messages", [])]
    provider_name = data.get("provider", settings.default_provider)
    model = data.get("model", "")

    provider = provider_manager.get_provider(provider_name)
    result = cost_optimizer.analyze_context(
        messages, lambda text: provider.count_tokens(text, model)
    )

    return result.model_dump()


@app.post("/tools/execute")
async def execute_tool(data: dict):
    """Execute a tool directly."""
    tool_name = data.get("tool_name")
    arguments = data.get("arguments", {})

    if not tool_name:
        raise HTTPException(status_code=400, detail="tool_name is required")

    try:
        result = await tool_registry.execute_tool(tool_name, arguments)
        return {"success": True, "result": result}
    except Exception as e:
        logger.error(f"Tool execution error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=settings.app_env == "development",
        log_level=settings.log_level.lower(),
    )
