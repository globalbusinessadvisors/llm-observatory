import { create } from 'zustand';
import { devtools } from 'zustand/middleware';
import {
  ConversationMetrics,
  CostMetrics,
  PerformanceMetrics,
  ModelUsageStats,
  TimeSeriesDataPoint,
} from '@/types';
import { analyticsApi } from '@/api/client';

interface AnalyticsState {
  // State
  conversationMetrics: ConversationMetrics | null;
  costMetrics: CostMetrics | null;
  performanceMetrics: PerformanceMetrics | null;
  modelUsageStats: ModelUsageStats[];
  timeSeriesData: Record<string, TimeSeriesDataPoint[]>;

  isLoading: boolean;
  error: string | null;

  dateRange: {
    startDate: string;
    endDate: string;
  };

  // Actions
  setDateRange: (startDate: string, endDate: string) => void;
  fetchConversationMetrics: () => Promise<void>;
  fetchCostMetrics: () => Promise<void>;
  fetchPerformanceMetrics: () => Promise<void>;
  fetchModelUsageStats: () => Promise<void>;
  fetchTimeSeriesData: (metric: string, granularity?: 'hour' | 'day' | 'week') => Promise<void>;
  fetchAllMetrics: () => Promise<void>;

  clearError: () => void;
  reset: () => void;
}

const getDefaultDateRange = () => {
  const endDate = new Date();
  const startDate = new Date();
  startDate.setDate(startDate.getDate() - 7); // Last 7 days

  return {
    startDate: startDate.toISOString().split('T')[0],
    endDate: endDate.toISOString().split('T')[0],
  };
};

const initialState = {
  conversationMetrics: null,
  costMetrics: null,
  performanceMetrics: null,
  modelUsageStats: [],
  timeSeriesData: {},
  isLoading: false,
  error: null,
  dateRange: getDefaultDateRange(),
};

export const useAnalyticsStore = create<AnalyticsState>()(
  devtools(
    (set, get) => ({
      ...initialState,

      setDateRange: (startDate: string, endDate: string) => {
        set({ dateRange: { startDate, endDate } });
      },

      fetchConversationMetrics: async () => {
        set({ isLoading: true, error: null });
        try {
          const { startDate, endDate } = get().dateRange;
          const metrics = await analyticsApi.getConversationMetrics(startDate, endDate);
          set({ conversationMetrics: metrics, isLoading: false });
        } catch (error) {
          set({
            error: error instanceof Error ? error.message : 'Failed to fetch conversation metrics',
            isLoading: false
          });
        }
      },

      fetchCostMetrics: async () => {
        set({ isLoading: true, error: null });
        try {
          const { startDate, endDate } = get().dateRange;
          const metrics = await analyticsApi.getCostMetrics(startDate, endDate);
          set({ costMetrics: metrics, isLoading: false });
        } catch (error) {
          set({
            error: error instanceof Error ? error.message : 'Failed to fetch cost metrics',
            isLoading: false
          });
        }
      },

      fetchPerformanceMetrics: async () => {
        set({ isLoading: true, error: null });
        try {
          const { startDate, endDate } = get().dateRange;
          const metrics = await analyticsApi.getPerformanceMetrics(startDate, endDate);
          set({ performanceMetrics: metrics, isLoading: false });
        } catch (error) {
          set({
            error: error instanceof Error ? error.message : 'Failed to fetch performance metrics',
            isLoading: false
          });
        }
      },

      fetchModelUsageStats: async () => {
        set({ isLoading: true, error: null });
        try {
          const { startDate, endDate } = get().dateRange;
          const stats = await analyticsApi.getModelUsageStats(startDate, endDate);
          set({ modelUsageStats: stats, isLoading: false });
        } catch (error) {
          set({
            error: error instanceof Error ? error.message : 'Failed to fetch model usage stats',
            isLoading: false
          });
        }
      },

      fetchTimeSeriesData: async (
        metric: string,
        granularity: 'hour' | 'day' | 'week' = 'day'
      ) => {
        set({ isLoading: true, error: null });
        try {
          const { startDate, endDate } = get().dateRange;
          const data = await analyticsApi.getTimeSeriesData(
            metric,
            startDate,
            endDate,
            granularity
          );
          set((state) => ({
            timeSeriesData: {
              ...state.timeSeriesData,
              [metric]: data,
            },
            isLoading: false,
          }));
        } catch (error) {
          set({
            error: error instanceof Error ? error.message : 'Failed to fetch time series data',
            isLoading: false
          });
        }
      },

      fetchAllMetrics: async () => {
        set({ isLoading: true, error: null });
        try {
          const { startDate, endDate } = get().dateRange;

          const [
            conversationMetrics,
            costMetrics,
            performanceMetrics,
            modelUsageStats,
          ] = await Promise.all([
            analyticsApi.getConversationMetrics(startDate, endDate),
            analyticsApi.getCostMetrics(startDate, endDate),
            analyticsApi.getPerformanceMetrics(startDate, endDate),
            analyticsApi.getModelUsageStats(startDate, endDate),
          ]);

          set({
            conversationMetrics,
            costMetrics,
            performanceMetrics,
            modelUsageStats,
            isLoading: false,
          });
        } catch (error) {
          set({
            error: error instanceof Error ? error.message : 'Failed to fetch metrics',
            isLoading: false
          });
        }
      },

      clearError: () => set({ error: null }),

      reset: () => set({ ...initialState, dateRange: getDefaultDateRange() }),
    }),
    { name: 'AnalyticsStore' }
  )
);
