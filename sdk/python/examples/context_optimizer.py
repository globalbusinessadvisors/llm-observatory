#!/usr/bin/env python3
# Copyright 2025 LLM Observatory Contributors
# SPDX-License-Identifier: Apache-2.0

"""
Context window optimization example.

This example shows how to use the ContextWindowOptimizer to manage
conversation history and prevent token limit errors.
"""

import os
from openai import OpenAI
from llm_observatory import LLMObservatory, instrument_openai
from llm_observatory.optimizers import ContextWindowOptimizer


def main():
    # Initialize observatory
    observatory = LLMObservatory(
        service_name="context-optimizer-example",
        otlp_endpoint="http://localhost:4317",
    )

    # Create and instrument OpenAI client
    client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))
    instrument_openai(client)

    # Create context window optimizer for gpt-3.5-turbo
    optimizer = ContextWindowOptimizer(
        model="gpt-3.5-turbo",
        warning_threshold=0.7,  # Warn at 70%
        action_threshold=0.85,  # Optimize at 85%
    )

    # Simulate a long conversation
    messages = [
        {"role": "system", "content": "You are a helpful assistant."},
        {"role": "user", "content": "Tell me about Python."},
        {"role": "assistant", "content": "Python is a high-level programming language..."},
        {"role": "user", "content": "What about its history?"},
        {"role": "assistant", "content": "Python was created by Guido van Rossum..."},
        # ... many more messages ...
    ]

    # Add more messages to simulate a long conversation
    for i in range(20):
        messages.append({
            "role": "user",
            "content": f"This is question number {i+1}. " * 50  # Long message
        })
        messages.append({
            "role": "assistant",
            "content": f"This is answer number {i+1}. " * 50  # Long message
        })

    # Check context window
    check = optimizer.check_context_window(messages)
    print(f"Context window utilization: {check['utilization']:.1%}")
    print(f"Estimated tokens: {check['estimated_tokens']}/{check['available_tokens']}")

    # Get optimization suggestion
    suggestion = optimizer.get_optimization_suggestion(messages)
    if suggestion:
        print(f"\nSuggestion: {suggestion}")

    # Optimize messages if needed
    if check['should_optimize']:
        print("\nOptimizing messages...")
        optimized = optimizer.optimize_messages(messages, strategy="truncate_old")
        print(f"Reduced from {len(messages)} to {len(optimized)} messages")

        # Use optimized messages for API call
        messages = optimized

    # Make API call with optimized messages
    print("\nMaking API call with optimized context...")
    response = client.chat.completions.create(
        model="gpt-3.5-turbo",
        messages=messages,
        max_tokens=100,
    )

    print(f"Response: {response.choices[0].message.content}")

    observatory.shutdown()


if __name__ == "__main__":
    main()
