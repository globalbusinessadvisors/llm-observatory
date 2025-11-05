#!/usr/bin/env python3
# Copyright 2025 LLM Observatory Contributors
# SPDX-License-Identifier: Apache-2.0

"""
Anthropic Claude instrumentation example.

This example shows how to instrument Anthropic's Claude API client.
"""

import os
from anthropic import Anthropic
from llm_observatory import LLMObservatory, instrument_anthropic


def main():
    # Initialize observatory
    observatory = LLMObservatory(
        service_name="anthropic-example",
        otlp_endpoint="http://localhost:4317",
    )

    # Create Anthropic client
    client = Anthropic(api_key=os.getenv("ANTHROPIC_API_KEY"))

    # Instrument the client
    instrument_anthropic(client)

    print("Making Anthropic API call...")

    # Make a messages request
    response = client.messages.create(
        model="claude-3-opus-20240229",
        max_tokens=1024,
        messages=[
            {"role": "user", "content": "Explain the benefits of observability in AI systems."}
        ]
    )

    print(f"Response: {response.content[0].text}")

    # Telemetry automatically includes:
    # - Model: claude-3-opus-20240229
    # - Provider: anthropic
    # - Token usage and cost
    # - All request/response parameters

    observatory.shutdown()


if __name__ == "__main__":
    main()
