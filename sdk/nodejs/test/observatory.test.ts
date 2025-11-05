// Copyright 2025 LLM Observatory Contributors
// SPDX-License-Identifier: Apache-2.0

import { LLMObservatory, initObservatory, getObservatory, shutdownObservatory } from '../src/observatory';
import { ObservatoryConfig, ErrorType, ObservatoryError } from '../src/types';

describe('LLMObservatory', () => {
  afterEach(async () => {
    // Clean up after each test
    await shutdownObservatory();
  });

  describe('initialization', () => {
    it('should initialize with minimal config', async () => {
      const config: ObservatoryConfig = {
        serviceName: 'test-service',
      };

      const observatory = new LLMObservatory(config);
      await observatory.init();

      expect(observatory.isInitialized()).toBe(true);
      expect(observatory.getConfig().serviceName).toBe('test-service');

      await observatory.shutdown();
    });

    it('should initialize with full config', async () => {
      const config: ObservatoryConfig = {
        serviceName: 'test-service',
        serviceVersion: '1.0.0',
        otlpEndpoint: 'http://localhost:4317',
        useGrpc: true,
        enableMetrics: true,
        enableTraces: true,
        sampleRate: 0.5,
        environment: 'test',
        debug: false,
        exportIntervalMs: 5000,
        maxBatchSize: 512,
      };

      const observatory = new LLMObservatory(config);
      await observatory.init();

      expect(observatory.isInitialized()).toBe(true);
      const savedConfig = observatory.getConfig();
      expect(savedConfig.serviceName).toBe('test-service');
      expect(savedConfig.serviceVersion).toBe('1.0.0');
      expect(savedConfig.sampleRate).toBe(0.5);

      await observatory.shutdown();
    });

    it('should throw error for missing service name', () => {
      expect(() => {
        new LLMObservatory({} as any);
      }).toThrow(ObservatoryError);
    });

    it('should throw error for invalid sample rate', () => {
      expect(() => {
        new LLMObservatory({
          serviceName: 'test',
          sampleRate: 1.5,
        });
      }).toThrow(ObservatoryError);
    });

    it('should not initialize twice', async () => {
      const observatory = new LLMObservatory({ serviceName: 'test' });
      await observatory.init();

      // Should not throw, just warn
      await observatory.init();

      expect(observatory.isInitialized()).toBe(true);
      await observatory.shutdown();
    });
  });

  describe('global instance', () => {
    it('should create global instance', async () => {
      const observatory = await initObservatory({
        serviceName: 'global-test',
      });

      expect(observatory.isInitialized()).toBe(true);

      const retrieved = getObservatory();
      expect(retrieved).toBe(observatory);

      await shutdownObservatory();
    });

    it('should throw error when getting uninitialized global', () => {
      expect(() => {
        getObservatory();
      }).toThrow(ObservatoryError);
    });

    it('should return existing instance on second init', async () => {
      const first = await initObservatory({ serviceName: 'test' });
      const second = await initObservatory({ serviceName: 'test2' });

      expect(first).toBe(second);

      await shutdownObservatory();
    });
  });

  describe('tracer', () => {
    it('should provide tracer instance', async () => {
      const observatory = new LLMObservatory({ serviceName: 'test' });
      await observatory.init();

      const tracer = observatory.getTracer();
      expect(tracer).toBeDefined();

      await observatory.shutdown();
    });
  });

  describe('middleware', () => {
    it('should create middleware', async () => {
      const observatory = new LLMObservatory({ serviceName: 'test' });
      await observatory.init();

      const middleware = observatory.middleware();
      expect(middleware).toBeInstanceOf(Function);

      await observatory.shutdown();
    });

    it('should throw error if not initialized', () => {
      const observatory = new LLMObservatory({ serviceName: 'test' });

      expect(() => {
        observatory.middleware();
      }).toThrow(ObservatoryError);
    });
  });

  describe('shutdown and flush', () => {
    it('should shutdown cleanly', async () => {
      const observatory = new LLMObservatory({ serviceName: 'test' });
      await observatory.init();
      await observatory.shutdown();

      expect(observatory.isInitialized()).toBe(false);
    });

    it('should flush telemetry data', async () => {
      const observatory = new LLMObservatory({ serviceName: 'test' });
      await observatory.init();

      // Should not throw
      await observatory.flush();

      await observatory.shutdown();
    });

    it('should handle shutdown when not initialized', async () => {
      const observatory = new LLMObservatory({ serviceName: 'test' });

      // Should not throw
      await observatory.shutdown();
    });

    it('should handle flush when not initialized', async () => {
      const observatory = new LLMObservatory({ serviceName: 'test' });

      // Should not throw
      await observatory.flush();
    });
  });
});
