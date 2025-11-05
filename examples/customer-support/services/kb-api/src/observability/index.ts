import { NodeSDK } from '@opentelemetry/sdk-node';
import { getNodeAutoInstrumentations } from '@opentelemetry/auto-instrumentations-node';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-grpc';
import { OTLPMetricExporter } from '@opentelemetry/exporter-metrics-otlp-grpc';
import { PeriodicExportingMetricReader } from '@opentelemetry/sdk-metrics';
import { Resource } from '@opentelemetry/resources';
import { SemanticResourceAttributes } from '@opentelemetry/semantic-conventions';
import { config } from '../config';
import logger from '../utils/logger';

let sdk: NodeSDK | null = null;

export function initializeObservability(): void {
  if (!config.observatory.enabled) {
    logger.info('LLM Observatory is disabled');
    return;
  }

  try {
    logger.info('Initializing LLM Observatory', {
      collectorUrl: config.observatory.collectorUrl,
      serviceName: config.observatory.serviceName,
    });

    const resource = new Resource({
      [SemanticResourceAttributes.SERVICE_NAME]: config.observatory.serviceName,
      [SemanticResourceAttributes.SERVICE_VERSION]: config.observatory.serviceVersion,
      [SemanticResourceAttributes.DEPLOYMENT_ENVIRONMENT]: config.observatory.environment,
    });

    const traceExporter = new OTLPTraceExporter({
      url: config.observatory.collectorUrl,
    });

    const metricExporter = new OTLPMetricExporter({
      url: config.observatory.collectorUrl,
    });

    const metricReader = new PeriodicExportingMetricReader({
      exporter: metricExporter,
      exportIntervalMillis: 60000, // 1 minute
    });

    sdk = new NodeSDK({
      resource,
      traceExporter,
      metricReader,
      instrumentations: [
        getNodeAutoInstrumentations({
          '@opentelemetry/instrumentation-fs': {
            enabled: false,
          },
        }),
      ],
    });

    sdk.start();

    logger.info('LLM Observatory initialized successfully');

    // Graceful shutdown
    process.on('SIGTERM', () => {
      shutdownObservability();
    });
  } catch (error) {
    logger.error('Failed to initialize LLM Observatory', { error });
    // Don't throw - allow service to start without observability
  }
}

export async function shutdownObservability(): Promise<void> {
  if (sdk) {
    try {
      await sdk.shutdown();
      logger.info('LLM Observatory shut down successfully');
    } catch (error) {
      logger.error('Failed to shut down LLM Observatory', { error });
    }
  }
}

export default { initializeObservability, shutdownObservability };
