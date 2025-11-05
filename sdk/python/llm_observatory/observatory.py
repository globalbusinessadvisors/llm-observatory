# Copyright 2025 LLM Observatory Contributors
# SPDX-License-Identifier: Apache-2.0

"""
Main LLMObservatory class for initializing and managing observability.
"""

import atexit
from typing import Optional

from llm_observatory.tracing import (
    TracingConfig,
    initialize_tracing,
    shutdown_tracing,
)
from llm_observatory.cost import CostCalculator


class LLMObservatory:
    """
    Main class for LLM Observatory Python SDK.

    This class initializes OpenTelemetry tracing and provides the foundation
    for auto-instrumentation of LLM providers.

    Example:
        >>> observatory = LLMObservatory(
        ...     service_name="my-llm-app",
        ...     otlp_endpoint="http://localhost:4317"
        ... )
        >>> # Your LLM calls are now instrumented
    """

    def __init__(
        self,
        service_name: str,
        service_version: str = "0.1.0",
        otlp_endpoint: Optional[str] = None,
        insecure: bool = True,
        console_export: bool = False,
        auto_shutdown: bool = True,
    ):
        """
        Initialize LLM Observatory.

        Args:
            service_name: Name of your service/application
            service_version: Version of your service
            otlp_endpoint: OTLP collector endpoint (e.g., "localhost:4317")
                          If None, traces won't be exported (useful for testing)
            insecure: Whether to use insecure gRPC connection
            console_export: Also export to console (for debugging)
            auto_shutdown: Automatically shutdown on exit
        """
        self.service_name = service_name
        self.service_version = service_version
        self.otlp_endpoint = otlp_endpoint
        self.cost_calculator = CostCalculator()

        # Create tracing configuration
        config = TracingConfig(
            service_name=service_name,
            service_version=service_version,
            otlp_endpoint=otlp_endpoint,
            insecure=insecure,
            console_export=console_export,
        )

        # Initialize tracing
        initialize_tracing(config)

        # Register shutdown handler
        if auto_shutdown:
            atexit.register(self.shutdown)

    def shutdown(self) -> None:
        """
        Shutdown observatory and flush remaining telemetry data.

        This is automatically called on exit if auto_shutdown=True.
        """
        shutdown_tracing()

    def __enter__(self):
        """Context manager entry."""
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        """Context manager exit."""
        self.shutdown()
        return False

    @classmethod
    def from_env(cls, auto_shutdown: bool = True) -> "LLMObservatory":
        """
        Create LLMObservatory from environment variables.

        Environment variables:
            - LLM_OBSERVATORY_SERVICE_NAME: Service name (required)
            - LLM_OBSERVATORY_SERVICE_VERSION: Service version (default: "0.1.0")
            - LLM_OBSERVATORY_OTLP_ENDPOINT: OTLP endpoint (default: "localhost:4317")
            - LLM_OBSERVATORY_CONSOLE_EXPORT: Console export (default: "false")

        Returns:
            LLMObservatory instance

        Raises:
            ValueError: If required environment variables are not set
        """
        import os

        service_name = os.getenv("LLM_OBSERVATORY_SERVICE_NAME")
        if not service_name:
            raise ValueError("LLM_OBSERVATORY_SERVICE_NAME environment variable is required")

        service_version = os.getenv("LLM_OBSERVATORY_SERVICE_VERSION", "0.1.0")
        otlp_endpoint = os.getenv("LLM_OBSERVATORY_OTLP_ENDPOINT", "localhost:4317")
        console_export = os.getenv("LLM_OBSERVATORY_CONSOLE_EXPORT", "false").lower() == "true"

        return cls(
            service_name=service_name,
            service_version=service_version,
            otlp_endpoint=otlp_endpoint,
            console_export=console_export,
            auto_shutdown=auto_shutdown,
        )
