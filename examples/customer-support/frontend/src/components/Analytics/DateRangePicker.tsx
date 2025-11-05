import { useState } from 'react';
import { useAnalyticsStore } from '@/stores/analyticsStore';
import { Calendar } from 'lucide-react';

export default function DateRangePicker() {
  const { dateRange, setDateRange, fetchAllMetrics } = useAnalyticsStore();
  const [isOpen, setIsOpen] = useState(false);

  const handleApply = (startDate: string, endDate: string) => {
    setDateRange(startDate, endDate);
    fetchAllMetrics();
    setIsOpen(false);
  };

  const presets = [
    { label: 'Last 7 days', days: 7 },
    { label: 'Last 30 days', days: 30 },
    { label: 'Last 90 days', days: 90 },
  ];

  const handlePreset = (days: number) => {
    const endDate = new Date();
    const startDate = new Date();
    startDate.setDate(startDate.getDate() - days);

    handleApply(
      startDate.toISOString().split('T')[0],
      endDate.toISOString().split('T')[0]
    );
  };

  return (
    <div className="relative">
      <button
        onClick={() => setIsOpen(!isOpen)}
        className="flex items-center gap-2 rounded-lg border border-gray-300 bg-white px-4 py-2 text-sm font-medium text-gray-700 transition-colors hover:bg-gray-50"
      >
        <Calendar className="h-4 w-4" />
        <span>
          {dateRange.startDate} - {dateRange.endDate}
        </span>
      </button>

      {isOpen && (
        <>
          <div
            className="fixed inset-0 z-10"
            onClick={() => setIsOpen(false)}
          />
          <div className="absolute right-0 z-20 mt-2 w-80 rounded-lg border border-gray-200 bg-white p-4 shadow-lg">
            <div className="space-y-4">
              <div>
                <h3 className="mb-2 text-sm font-medium text-gray-900">Quick Select</h3>
                <div className="flex flex-wrap gap-2">
                  {presets.map((preset) => (
                    <button
                      key={preset.days}
                      onClick={() => handlePreset(preset.days)}
                      className="rounded-md bg-gray-100 px-3 py-1.5 text-xs font-medium text-gray-700 transition-colors hover:bg-gray-200"
                    >
                      {preset.label}
                    </button>
                  ))}
                </div>
              </div>

              <div className="border-t border-gray-200 pt-4">
                <h3 className="mb-2 text-sm font-medium text-gray-900">Custom Range</h3>
                <div className="space-y-2">
                  <div>
                    <label className="block text-xs text-gray-600">Start Date</label>
                    <input
                      type="date"
                      value={dateRange.startDate}
                      onChange={(e) =>
                        setDateRange(e.target.value, dateRange.endDate)
                      }
                      className="mt-1 w-full rounded-md border border-gray-300 px-3 py-1.5 text-sm focus:border-primary-500 focus:outline-none focus:ring-2 focus:ring-primary-500/20"
                    />
                  </div>
                  <div>
                    <label className="block text-xs text-gray-600">End Date</label>
                    <input
                      type="date"
                      value={dateRange.endDate}
                      onChange={(e) =>
                        setDateRange(dateRange.startDate, e.target.value)
                      }
                      className="mt-1 w-full rounded-md border border-gray-300 px-3 py-1.5 text-sm focus:border-primary-500 focus:outline-none focus:ring-2 focus:ring-primary-500/20"
                    />
                  </div>
                </div>
              </div>

              <div className="flex justify-end gap-2 border-t border-gray-200 pt-4">
                <button
                  onClick={() => setIsOpen(false)}
                  className="rounded-md px-3 py-1.5 text-sm font-medium text-gray-700 transition-colors hover:bg-gray-100"
                >
                  Cancel
                </button>
                <button
                  onClick={() => handleApply(dateRange.startDate, dateRange.endDate)}
                  className="rounded-md bg-primary-600 px-3 py-1.5 text-sm font-medium text-white transition-colors hover:bg-primary-700"
                >
                  Apply
                </button>
              </div>
            </div>
          </div>
        </>
      )}
    </div>
  );
}
