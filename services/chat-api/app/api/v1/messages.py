"""Message and chat endpoints."""

import json
from typing import List
from fastapi import APIRouter, Depends, HTTPException, Query, status
from fastapi.responses import StreamingResponse
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database.session import get_db
from app.database.models import Conversation, Message, MessageRoleEnum
from app.models.schemas import (
    MessageCreate,
    MessageResponse,
    MessageListResponse,
    ChatRequest,
    ChatResponse,
)
from app.services.llm import llm_service
from app.core.logging import get_logger

logger = get_logger(__name__)
router = APIRouter()


@router.post("/conversations/{conversation_id}/messages", response_model=ChatResponse)
async def send_message(
    conversation_id: str,
    request: ChatRequest,
    db: AsyncSession = Depends(get_db),
):
    """Send a message and get LLM response.

    Args:
        conversation_id: Conversation ID
        request: Chat request data
        db: Database session

    Returns:
        Chat response with message and metadata
    """
    try:
        # Verify conversation exists
        query = select(Conversation).where(Conversation.id == conversation_id)
        result = await db.execute(query)
        conversation = result.scalar_one_or_none()

        if not conversation:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Conversation {conversation_id} not found"
            )

        # Get conversation history
        history_query = (
            select(Message)
            .where(Message.conversation_id == conversation_id)
            .order_by(Message.created_at.asc())
        )
        history_result = await db.execute(history_query)
        history = history_result.scalars().all()

        # Build messages for LLM
        llm_messages = [
            {"role": msg.role.value, "content": msg.content}
            for msg in history
        ]

        # Add user message
        user_message = Message(
            conversation_id=conversation_id,
            role=MessageRoleEnum.USER,
            content=request.message,
            metadata=request.metadata,
        )
        db.add(user_message)
        await db.flush()

        llm_messages.append({
            "role": MessageRoleEnum.USER.value,
            "content": request.message,
        })

        # Get LLM response
        if request.stream:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Use /conversations/{id}/stream endpoint for streaming"
            )

        completion = await llm_service.chat_completion(
            messages=llm_messages,
            provider=request.provider,
            model=request.model,
            temperature=request.temperature,
            max_tokens=request.max_tokens,
        )

        # Save assistant message
        assistant_message = Message(
            conversation_id=conversation_id,
            role=MessageRoleEnum.ASSISTANT,
            content=completion["content"],
            provider=completion["provider"],
            model=completion["model"],
            prompt_tokens=completion["prompt_tokens"],
            completion_tokens=completion["completion_tokens"],
            total_tokens=completion["total_tokens"],
            cost_usd=completion["cost_usd"],
            latency_ms=completion["latency_ms"],
            metadata={"finish_reason": completion.get("finish_reason")},
        )
        db.add(assistant_message)

        await db.commit()
        await db.refresh(user_message)
        await db.refresh(assistant_message)

        logger.info(
            f"Chat completion for conversation {conversation_id}: "
            f"model={completion['model']}, "
            f"tokens={completion['total_tokens']}, "
            f"cost=${completion['cost_usd']:.6f}, "
            f"latency={completion['latency_ms']}ms"
        )

        return ChatResponse(
            message=MessageResponse.model_validate(assistant_message),
            conversation_id=conversation_id,
            usage={
                "prompt_tokens": completion["prompt_tokens"],
                "completion_tokens": completion["completion_tokens"],
                "total_tokens": completion["total_tokens"],
            },
            cost_usd=completion["cost_usd"],
        )

    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        logger.error(f"Failed to send message: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to generate response: {str(e)}"
        )


@router.get("/conversations/{conversation_id}/messages", response_model=MessageListResponse)
async def get_messages(
    conversation_id: str,
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_db),
):
    """Get messages for a conversation.

    Args:
        conversation_id: Conversation ID
        limit: Maximum number of messages
        offset: Number of messages to skip
        db: Database session

    Returns:
        List of messages
    """
    try:
        # Verify conversation exists
        conv_query = select(Conversation).where(Conversation.id == conversation_id)
        conv_result = await db.execute(conv_query)
        conversation = conv_result.scalar_one_or_none()

        if not conversation:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Conversation {conversation_id} not found"
            )

        # Get messages
        query = (
            select(Message)
            .where(Message.conversation_id == conversation_id)
            .order_by(Message.created_at.asc())
            .limit(limit)
            .offset(offset)
        )

        result = await db.execute(query)
        messages = result.scalars().all()

        # Get total count
        from sqlalchemy import func
        count_query = select(func.count()).select_from(Message).where(
            Message.conversation_id == conversation_id
        )
        count_result = await db.execute(count_query)
        total = count_result.scalar()

        logger.info(f"Retrieved {len(messages)} messages for conversation {conversation_id}")

        return MessageListResponse(
            messages=[MessageResponse.model_validate(msg) for msg in messages],
            total=total,
            limit=limit,
            offset=offset,
        )

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to get messages: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to retrieve messages"
        )


@router.get("/conversations/{conversation_id}/stream")
async def stream_message(
    conversation_id: str,
    message: str = Query(..., min_length=1),
    provider: str = Query(None),
    model: str = Query(None),
    temperature: float = Query(None, ge=0.0, le=2.0),
    max_tokens: int = Query(None, ge=1),
    db: AsyncSession = Depends(get_db),
):
    """Stream a chat completion response (Server-Sent Events).

    Args:
        conversation_id: Conversation ID
        message: User message
        provider: LLM provider
        model: Model name
        temperature: Sampling temperature
        max_tokens: Maximum tokens
        db: Database session

    Returns:
        SSE stream of response chunks
    """
    try:
        # Verify conversation exists
        query = select(Conversation).where(Conversation.id == conversation_id)
        result = await db.execute(query)
        conversation = result.scalar_one_or_none()

        if not conversation:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Conversation {conversation_id} not found"
            )

        # Get conversation history
        history_query = (
            select(Message)
            .where(Message.conversation_id == conversation_id)
            .order_by(Message.created_at.asc())
        )
        history_result = await db.execute(history_query)
        history = history_result.scalars().all()

        # Build messages
        llm_messages = [
            {"role": msg.role.value, "content": msg.content}
            for msg in history
        ]

        # Add user message
        user_message = Message(
            conversation_id=conversation_id,
            role=MessageRoleEnum.USER,
            content=message,
        )
        db.add(user_message)
        await db.flush()

        llm_messages.append({
            "role": MessageRoleEnum.USER.value,
            "content": message,
        })

        await db.commit()
        await db.refresh(user_message)

        # Stream response
        async def event_generator():
            """Generate SSE events."""
            try:
                total_content = ""
                metadata = {}

                async for chunk in llm_service.stream_completion(
                    messages=llm_messages,
                    provider=provider,
                    model=model,
                    temperature=temperature,
                    max_tokens=max_tokens,
                ):
                    if not chunk.get("done"):
                        # Stream content chunk
                        yield f"data: {json.dumps({'content': chunk['content'], 'done': False})}\n\n"
                        total_content += chunk["content"]
                    else:
                        # Final chunk with metadata
                        metadata = chunk

                # Save assistant message to database
                async with AsyncSession(db.bind) as session:
                    assistant_message = Message(
                        conversation_id=conversation_id,
                        role=MessageRoleEnum.ASSISTANT,
                        content=metadata.get("total_content", total_content),
                        provider=metadata.get("provider"),
                        model=metadata.get("model"),
                        latency_ms=metadata.get("latency_ms"),
                        time_to_first_token_ms=metadata.get("time_to_first_token_ms"),
                    )
                    session.add(assistant_message)
                    await session.commit()
                    await session.refresh(assistant_message)

                    # Send final event with message ID
                    yield f"data: {json.dumps({'content': '', 'done': True, 'message_id': assistant_message.id})}\n\n"

                logger.info(f"Completed streaming for conversation {conversation_id}")

            except Exception as e:
                logger.error(f"Streaming error: {e}", exc_info=True)
                yield f"data: {json.dumps({'error': str(e), 'done': True})}\n\n"

        return StreamingResponse(
            event_generator(),
            media_type="text/event-stream",
            headers={
                "Cache-Control": "no-cache",
                "Connection": "keep-alive",
                "X-Accel-Buffering": "no",
            }
        )

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to start streaming: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to start streaming: {str(e)}"
        )
