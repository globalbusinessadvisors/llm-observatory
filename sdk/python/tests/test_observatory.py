# Copyright 2025 LLM Observatory Contributors
# SPDX-License-Identifier: Apache-2.0

"""Tests for main LLMObservatory class."""

import pytest
import os
from unittest.mock import patch, Mock
from llm_observatory.observatory import LLMObservatory


class TestLLMObservatory:
    """Test LLMObservatory class."""

    def test_initialization(self):
        """Test basic initialization."""
        observatory = LLMObservatory(
            service_name="test-service",
            otlp_endpoint=None,  # Don't actually export
            auto_shutdown=False,
        )
        assert observatory.service_name == "test-service"
        assert observatory.service_version == "0.1.0"
        assert observatory.cost_calculator is not None

    def test_initialization_with_custom_version(self):
        """Test initialization with custom version."""
        observatory = LLMObservatory(
            service_name="test-service",
            service_version="2.0.0",
            otlp_endpoint=None,
            auto_shutdown=False,
        )
        assert observatory.service_version == "2.0.0"

    def test_initialization_with_otlp(self):
        """Test initialization with OTLP endpoint."""
        observatory = LLMObservatory(
            service_name="test-service",
            otlp_endpoint="localhost:4317",
            auto_shutdown=False,
        )
        assert observatory.otlp_endpoint == "localhost:4317"

    def test_context_manager(self):
        """Test using observatory as context manager."""
        with LLMObservatory(
            service_name="test-service",
            otlp_endpoint=None,
            auto_shutdown=False,
        ) as observatory:
            assert observatory is not None
        # Should shutdown on exit

    def test_manual_shutdown(self):
        """Test manual shutdown."""
        observatory = LLMObservatory(
            service_name="test-service",
            otlp_endpoint=None,
            auto_shutdown=False,
        )
        # Should not raise
        observatory.shutdown()

    def test_from_env_missing_service_name(self):
        """Test from_env with missing service name."""
        # Ensure env var is not set
        os.environ.pop("LLM_OBSERVATORY_SERVICE_NAME", None)

        with pytest.raises(ValueError, match="SERVICE_NAME.*required"):
            LLMObservatory.from_env()

    def test_from_env_with_service_name(self):
        """Test from_env with service name set."""
        os.environ["LLM_OBSERVATORY_SERVICE_NAME"] = "env-test-service"
        try:
            observatory = LLMObservatory.from_env(auto_shutdown=False)
            assert observatory.service_name == "env-test-service"
            observatory.shutdown()
        finally:
            os.environ.pop("LLM_OBSERVATORY_SERVICE_NAME", None)

    def test_from_env_all_vars(self):
        """Test from_env with all environment variables."""
        os.environ["LLM_OBSERVATORY_SERVICE_NAME"] = "env-test-service"
        os.environ["LLM_OBSERVATORY_SERVICE_VERSION"] = "3.0.0"
        os.environ["LLM_OBSERVATORY_OTLP_ENDPOINT"] = "localhost:5000"
        os.environ["LLM_OBSERVATORY_CONSOLE_EXPORT"] = "true"

        try:
            observatory = LLMObservatory.from_env(auto_shutdown=False)
            assert observatory.service_name == "env-test-service"
            assert observatory.service_version == "3.0.0"
            assert observatory.otlp_endpoint == "localhost:5000"
            observatory.shutdown()
        finally:
            os.environ.pop("LLM_OBSERVATORY_SERVICE_NAME", None)
            os.environ.pop("LLM_OBSERVATORY_SERVICE_VERSION", None)
            os.environ.pop("LLM_OBSERVATORY_OTLP_ENDPOINT", None)
            os.environ.pop("LLM_OBSERVATORY_CONSOLE_EXPORT", None)

    def test_console_export_enabled(self):
        """Test with console export enabled."""
        observatory = LLMObservatory(
            service_name="test-service",
            otlp_endpoint=None,
            console_export=True,
            auto_shutdown=False,
        )
        # Should not raise
        observatory.shutdown()


class TestLLMObservatoryIntegration:
    """Integration tests for LLMObservatory."""

    def test_cost_calculator_available(self):
        """Test that cost calculator is available."""
        observatory = LLMObservatory(
            service_name="test-service",
            otlp_endpoint=None,
            auto_shutdown=False,
        )
        try:
            # Should have cost calculator
            assert observatory.cost_calculator is not None

            # Should be able to calculate costs
            cost = observatory.cost_calculator.calculate_cost("gpt-4", 1000, 500)
            assert cost is not None
            assert cost > 0
        finally:
            observatory.shutdown()

    def test_tracing_initialized(self):
        """Test that tracing is initialized."""
        from llm_observatory.tracing import get_tracer

        observatory = LLMObservatory(
            service_name="test-service",
            otlp_endpoint=None,
            auto_shutdown=False,
        )
        try:
            # Should be able to get tracer
            tracer = get_tracer()
            assert tracer is not None
        finally:
            observatory.shutdown()

    def test_multiple_observatories(self):
        """Test creating multiple observatory instances."""
        obs1 = LLMObservatory(
            service_name="service-1",
            otlp_endpoint=None,
            auto_shutdown=False,
        )
        obs2 = LLMObservatory(
            service_name="service-2",
            otlp_endpoint=None,
            auto_shutdown=False,
        )

        try:
            assert obs1.service_name == "service-1"
            assert obs2.service_name == "service-2"
        finally:
            obs1.shutdown()
            obs2.shutdown()


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
