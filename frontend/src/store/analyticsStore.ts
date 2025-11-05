import { create } from 'zustand'
import { devtools } from 'zustand/middleware'
import type { AnalyticsData } from '../types'
import { apiClient } from '../lib/api'

interface AnalyticsState {
  data: AnalyticsData | null
  isLoading: boolean
  error: string | null
  dateRange: {
    start: Date
    end: Date
  }

  // Actions
  fetchAnalytics: () => Promise<void>
  setDateRange: (start: Date, end: Date) => void
  refreshAnalytics: () => Promise<void>
  clearError: () => void
}

// Default to last 30 days
const getDefaultDateRange = () => {
  const end = new Date()
  const start = new Date()
  start.setDate(start.getDate() - 30)
  return { start, end }
}

export const useAnalyticsStore = create<AnalyticsState>()(
  devtools(
    (set, get) => ({
      data: null,
      isLoading: false,
      error: null,
      dateRange: getDefaultDateRange(),

      fetchAnalytics: async () => {
        set({ isLoading: true, error: null })
        try {
          const { start, end } = get().dateRange
          const data = await apiClient.getAnalytics(start, end)
          set({ data, isLoading: false })
        } catch (error) {
          set({
            error: error instanceof Error ? error.message : 'Failed to fetch analytics',
            isLoading: false
          })
        }
      },

      setDateRange: (start, end) => {
        set({ dateRange: { start, end } })
        get().fetchAnalytics()
      },

      refreshAnalytics: async () => {
        await get().fetchAnalytics()
      },

      clearError: () => set({ error: null })
    }),
    { name: 'analytics-store' }
  )
)
