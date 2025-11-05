#!/usr/bin/env python3
# Copyright 2025 LLM Observatory Contributors
# SPDX-License-Identifier: Apache-2.0

"""
Basic OpenAI instrumentation example.

This example shows how to instrument an OpenAI client and automatically
capture telemetry for all LLM calls.
"""

import os
from openai import OpenAI
from llm_observatory import LLMObservatory, instrument_openai


def main():
    # Initialize LLM Observatory
    observatory = LLMObservatory(
        service_name="openai-example",
        otlp_endpoint="http://localhost:4317",
        console_export=True,  # Also print to console for debugging
    )

    # Create OpenAI client
    client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))

    # Instrument the client for automatic tracing
    instrument_openai(client)

    print("Making OpenAI API call...")

    # Make a chat completion request
    # This call will be automatically traced with full telemetry
    response = client.chat.completions.create(
        model="gpt-4",
        messages=[
            {"role": "system", "content": "You are a helpful assistant."},
            {"role": "user", "content": "What is the capital of France?"}
        ],
        temperature=0.7,
        max_tokens=100,
    )

    print(f"Response: {response.choices[0].message.content}")

    # Telemetry data automatically includes:
    # - Model: gpt-4
    # - Provider: openai
    # - Request parameters: temperature, max_tokens, messages
    # - Response: content, finish_reason
    # - Token usage: prompt_tokens, completion_tokens, total_tokens
    # - Cost in USD
    # - Latency metrics

    # Shutdown observatory (flushes remaining traces)
    observatory.shutdown()


if __name__ == "__main__":
    main()
