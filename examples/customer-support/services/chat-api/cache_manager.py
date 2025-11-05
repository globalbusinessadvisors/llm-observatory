"""Redis-based caching for prompt responses."""
import json
import hashlib
import logging
from typing import Optional
from redis import Redis
from redis.exceptions import RedisError

from models import ChatResponse
from config import settings


logger = logging.getLogger(__name__)


class CacheManager:
    """Manages prompt caching using Redis."""

    def __init__(self):
        """Initialize cache manager."""
        try:
            self.redis = Redis(
                host=settings.redis_host,
                port=settings.redis_port,
                db=settings.redis_db,
                password=settings.redis_password,
                decode_responses=True,
                socket_connect_timeout=5,
            )
            # Test connection
            self.redis.ping()
            self.enabled = settings.enable_prompt_caching
            self.ttl = settings.cache_ttl_seconds
            logger.info("Cache manager initialized successfully")
        except RedisError as e:
            logger.warning(f"Redis connection failed: {e}. Caching disabled.")
            self.enabled = False
            self.redis = None

    def _generate_key(
        self,
        messages: list,
        model: str,
        temperature: float,
        max_tokens: Optional[int],
    ) -> str:
        """Generate cache key from request parameters.

        Args:
            messages: List of messages
            model: Model identifier
            temperature: Temperature setting
            max_tokens: Max tokens setting

        Returns:
            Cache key hash
        """
        # Create a stable representation of the request
        cache_data = {
            "messages": [{"role": m.role, "content": m.content} for m in messages],
            "model": model,
            "temperature": temperature,
            "max_tokens": max_tokens,
        }

        # Generate hash
        cache_str = json.dumps(cache_data, sort_keys=True)
        cache_hash = hashlib.sha256(cache_str.encode()).hexdigest()
        return f"llm_cache:{cache_hash}"

    def get(
        self,
        messages: list,
        model: str,
        temperature: float,
        max_tokens: Optional[int],
    ) -> Optional[ChatResponse]:
        """Retrieve cached response if available.

        Args:
            messages: List of messages
            model: Model identifier
            temperature: Temperature setting
            max_tokens: Max tokens setting

        Returns:
            Cached ChatResponse or None if not found
        """
        if not self.enabled or not self.redis:
            return None

        try:
            key = self._generate_key(messages, model, temperature, max_tokens)
            cached_data = self.redis.get(key)

            if cached_data:
                logger.info(f"Cache hit for key: {key}")
                response_dict = json.loads(cached_data)
                response = ChatResponse(**response_dict)
                response.cached = True
                return response

            logger.debug(f"Cache miss for key: {key}")
            return None

        except (RedisError, json.JSONDecodeError) as e:
            logger.error(f"Cache retrieval error: {e}")
            return None

    def set(
        self,
        messages: list,
        model: str,
        temperature: float,
        max_tokens: Optional[int],
        response: ChatResponse,
    ) -> bool:
        """Store response in cache.

        Args:
            messages: List of messages
            model: Model identifier
            temperature: Temperature setting
            max_tokens: Max tokens setting
            response: Response to cache

        Returns:
            True if successfully cached
        """
        if not self.enabled or not self.redis:
            return False

        try:
            key = self._generate_key(messages, model, temperature, max_tokens)
            # Convert response to dict for JSON serialization
            response_dict = response.model_dump()
            cache_data = json.dumps(response_dict)

            self.redis.setex(key, self.ttl, cache_data)
            logger.info(f"Cached response with key: {key}")
            return True

        except (RedisError, TypeError) as e:
            logger.error(f"Cache storage error: {e}")
            return False

    def invalidate(
        self,
        messages: list,
        model: str,
        temperature: float,
        max_tokens: Optional[int],
    ) -> bool:
        """Invalidate cached response.

        Args:
            messages: List of messages
            model: Model identifier
            temperature: Temperature setting
            max_tokens: Max tokens setting

        Returns:
            True if successfully invalidated
        """
        if not self.enabled or not self.redis:
            return False

        try:
            key = self._generate_key(messages, model, temperature, max_tokens)
            deleted = self.redis.delete(key)
            logger.info(f"Invalidated cache key: {key}")
            return deleted > 0

        except RedisError as e:
            logger.error(f"Cache invalidation error: {e}")
            return False

    def clear_all(self) -> bool:
        """Clear all cached responses.

        Returns:
            True if successfully cleared
        """
        if not self.enabled or not self.redis:
            return False

        try:
            # Find all cache keys
            keys = self.redis.keys("llm_cache:*")
            if keys:
                self.redis.delete(*keys)
                logger.info(f"Cleared {len(keys)} cached responses")
            return True

        except RedisError as e:
            logger.error(f"Cache clear error: {e}")
            return False

    def get_stats(self) -> dict:
        """Get cache statistics.

        Returns:
            Dictionary with cache stats
        """
        if not self.enabled or not self.redis:
            return {"enabled": False}

        try:
            info = self.redis.info("stats")
            keys = self.redis.keys("llm_cache:*")

            return {
                "enabled": True,
                "total_keys": len(keys),
                "ttl_seconds": self.ttl,
                "keyspace_hits": info.get("keyspace_hits", 0),
                "keyspace_misses": info.get("keyspace_misses", 0),
            }

        except RedisError as e:
            logger.error(f"Error getting cache stats: {e}")
            return {"enabled": True, "error": str(e)}
