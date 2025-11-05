"""Conversation management endpoints."""

from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.database.session import get_db
from app.database.models import Conversation, Message, Feedback
from app.models.schemas import (
    ConversationCreate,
    ConversationUpdate,
    ConversationResponse,
    ConversationWithMessages,
    FeedbackCreate,
    FeedbackResponse,
)
from app.core.logging import get_logger

logger = get_logger(__name__)
router = APIRouter()


@router.post("", response_model=ConversationResponse, status_code=status.HTTP_201_CREATED)
async def create_conversation(
    conversation: ConversationCreate,
    db: AsyncSession = Depends(get_db),
):
    """Create a new conversation.

    Args:
        conversation: Conversation creation data
        db: Database session

    Returns:
        Created conversation
    """
    try:
        # Create conversation
        db_conversation = Conversation(
            user_id=conversation.user_id,
            title=conversation.title,
            metadata=conversation.metadata or {},
        )

        db.add(db_conversation)
        await db.commit()
        await db.refresh(db_conversation)

        logger.info(f"Created conversation {db_conversation.id}")
        return db_conversation

    except Exception as e:
        await db.rollback()
        logger.error(f"Failed to create conversation: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to create conversation"
        )


@router.get("", response_model=List[ConversationResponse])
async def list_conversations(
    user_id: Optional[str] = Query(None),
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_db),
):
    """List conversations with optional filtering.

    Args:
        user_id: Filter by user ID
        limit: Maximum number of results
        offset: Number of results to skip
        db: Database session

    Returns:
        List of conversations
    """
    try:
        # Build query
        query = select(Conversation).order_by(Conversation.updated_at.desc())

        if user_id:
            query = query.where(Conversation.user_id == user_id)

        query = query.limit(limit).offset(offset)

        # Execute query
        result = await db.execute(query)
        conversations = result.scalars().all()

        logger.info(f"Retrieved {len(conversations)} conversations")
        return conversations

    except Exception as e:
        logger.error(f"Failed to list conversations: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to retrieve conversations"
        )


@router.get("/{conversation_id}", response_model=ConversationWithMessages)
async def get_conversation(
    conversation_id: str,
    db: AsyncSession = Depends(get_db),
):
    """Get a conversation by ID with all messages.

    Args:
        conversation_id: Conversation ID
        db: Database session

    Returns:
        Conversation with messages
    """
    try:
        # Query with messages
        query = (
            select(Conversation)
            .options(selectinload(Conversation.messages))
            .where(Conversation.id == conversation_id)
        )

        result = await db.execute(query)
        conversation = result.scalar_one_or_none()

        if not conversation:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Conversation {conversation_id} not found"
            )

        logger.info(f"Retrieved conversation {conversation_id} with {len(conversation.messages)} messages")
        return conversation

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to get conversation: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to retrieve conversation"
        )


@router.patch("/{conversation_id}", response_model=ConversationResponse)
async def update_conversation(
    conversation_id: str,
    updates: ConversationUpdate,
    db: AsyncSession = Depends(get_db),
):
    """Update a conversation.

    Args:
        conversation_id: Conversation ID
        updates: Fields to update
        db: Database session

    Returns:
        Updated conversation
    """
    try:
        # Get conversation
        query = select(Conversation).where(Conversation.id == conversation_id)
        result = await db.execute(query)
        conversation = result.scalar_one_or_none()

        if not conversation:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Conversation {conversation_id} not found"
            )

        # Update fields
        if updates.title is not None:
            conversation.title = updates.title
        if updates.metadata is not None:
            conversation.metadata = updates.metadata

        await db.commit()
        await db.refresh(conversation)

        logger.info(f"Updated conversation {conversation_id}")
        return conversation

    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        logger.error(f"Failed to update conversation: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to update conversation"
        )


@router.delete("/{conversation_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_conversation(
    conversation_id: str,
    db: AsyncSession = Depends(get_db),
):
    """Delete a conversation.

    Args:
        conversation_id: Conversation ID
        db: Database session
    """
    try:
        # Get conversation
        query = select(Conversation).where(Conversation.id == conversation_id)
        result = await db.execute(query)
        conversation = result.scalar_one_or_none()

        if not conversation:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Conversation {conversation_id} not found"
            )

        # Delete conversation (cascade will handle messages)
        await db.delete(conversation)
        await db.commit()

        logger.info(f"Deleted conversation {conversation_id}")

    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        logger.error(f"Failed to delete conversation: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to delete conversation"
        )


@router.post("/{conversation_id}/feedback", response_model=FeedbackResponse, status_code=status.HTTP_201_CREATED)
async def create_feedback(
    conversation_id: str,
    feedback: FeedbackCreate,
    db: AsyncSession = Depends(get_db),
):
    """Create feedback for a conversation or message.

    Args:
        conversation_id: Conversation ID
        feedback: Feedback data
        db: Database session

    Returns:
        Created feedback
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

        # Create feedback
        db_feedback = Feedback(
            conversation_id=conversation_id,
            message_id=feedback.message_id,
            user_id=feedback.user_id,
            feedback_type=feedback.feedback_type,
            rating=feedback.rating,
            comment=feedback.comment,
            metadata=feedback.metadata or {},
        )

        db.add(db_feedback)
        await db.commit()
        await db.refresh(db_feedback)

        logger.info(f"Created feedback for conversation {conversation_id}")
        return db_feedback

    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        logger.error(f"Failed to create feedback: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to create feedback"
        )
