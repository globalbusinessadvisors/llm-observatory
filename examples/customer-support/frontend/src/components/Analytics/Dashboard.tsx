import { useEffect } from 'react';
import { useAnalyticsStore } from '@/stores/analyticsStore';
import {
  TrendingUp,
  MessageSquare,
  DollarSign,
  Clock,
  CheckCircle,
  Activity,
} from 'lucide-react';
import CostChart from './CostChart';
import PerformanceChart from './PerformanceChart';
import ModelUsageChart from './ModelUsageChart';
import DateRangePicker from './DateRangePicker';

export default function Dashboard() {
  const {
    conversationMetrics,
    costMetrics,
    performanceMetrics,
    modelUsageStats,
    isLoading,
    error,
    fetchAllMetrics,
  } = useAnalyticsStore();

  useEffect(() => {
    fetchAllMetrics();
  }, []);

  if (error) {
    return (
      <div className="flex h-full items-center justify-center">
        <div className="text-center">
          <p className="text-red-600">{error}</p>
        </div>
      </div>
    );
  }

  return (
    <div className="h-full overflow-y-auto bg-gray-50">
      <div className="mx-auto max-w-7xl space-y-6 p-6">
        {/* Header */}
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-2xl font-bold text-gray-900">Analytics Dashboard</h1>
            <p className="mt-1 text-sm text-gray-500">
              Monitor your AI customer support performance
            </p>
          </div>
          <DateRangePicker />
        </div>

        {/* Key Metrics Cards */}
        <div className="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3">
          {/* Total Conversations */}
          <MetricCard
            title="Total Conversations"
            value={conversationMetrics?.totalConversations || 0}
            icon={MessageSquare}
            color="blue"
            trend={
              conversationMetrics
                ? {
                    value: 12.5,
                    isPositive: true,
                  }
                : undefined
            }
          />

          {/* Resolution Rate */}
          <MetricCard
            title="Resolution Rate"
            value={
              conversationMetrics
                ? `${((conversationMetrics.resolvedConversations / conversationMetrics.totalConversations) * 100).toFixed(1)}%`
                : '0%'
            }
            icon={CheckCircle}
            color="green"
            trend={
              conversationMetrics
                ? {
                    value: 5.2,
                    isPositive: true,
                  }
                : undefined
            }
          />

          {/* Total Cost */}
          <MetricCard
            title="Total Cost"
            value={`$${costMetrics?.totalCost.toFixed(2) || '0.00'}`}
            icon={DollarSign}
            color="purple"
            trend={
              costMetrics
                ? {
                    value: 8.3,
                    isPositive: false,
                  }
                : undefined
            }
          />

          {/* Avg Resolution Time */}
          <MetricCard
            title="Avg Resolution Time"
            value={
              conversationMetrics
                ? `${(conversationMetrics.averageResolutionTime / 60).toFixed(1)} min`
                : '0 min'
            }
            icon={Clock}
            color="orange"
          />

          {/* Customer Satisfaction */}
          <MetricCard
            title="Customer Satisfaction"
            value={conversationMetrics?.customerSatisfactionScore.toFixed(1) || '0.0'}
            suffix="/5.0"
            icon={TrendingUp}
            color="green"
          />

          {/* Avg Latency */}
          <MetricCard
            title="Avg Latency"
            value={`${performanceMetrics?.averageLatency.toFixed(0) || 0}ms`}
            icon={Activity}
            color="blue"
          />
        </div>

        {/* Charts */}
        <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
          {/* Cost Chart */}
          <div className="rounded-lg bg-white p-6 shadow-sm">
            <h2 className="mb-4 text-lg font-semibold text-gray-900">Cost Trends</h2>
            <CostChart data={costMetrics?.costByDay || []} />
          </div>

          {/* Performance Chart */}
          <div className="rounded-lg bg-white p-6 shadow-sm">
            <h2 className="mb-4 text-lg font-semibold text-gray-900">
              Performance Metrics
            </h2>
            <PerformanceChart metrics={performanceMetrics} />
          </div>
        </div>

        {/* Model Usage */}
        <div className="rounded-lg bg-white p-6 shadow-sm">
          <h2 className="mb-4 text-lg font-semibold text-gray-900">Model Usage</h2>
          <ModelUsageChart data={modelUsageStats} />
        </div>

        {/* Detailed Stats Table */}
        {conversationMetrics && (
          <div className="rounded-lg bg-white p-6 shadow-sm">
            <h2 className="mb-4 text-lg font-semibold text-gray-900">
              Detailed Statistics
            </h2>
            <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
              <StatItem
                label="Active Conversations"
                value={conversationMetrics.activeConversations}
              />
              <StatItem
                label="Resolved Conversations"
                value={conversationMetrics.resolvedConversations}
              />
              <StatItem
                label="Avg Messages/Conversation"
                value={conversationMetrics.averageMessagesPerConversation.toFixed(1)}
              />
              {performanceMetrics && (
                <>
                  <StatItem
                    label="Total Tokens Used"
                    value={performanceMetrics.totalTokensUsed.toLocaleString()}
                  />
                  <StatItem
                    label="Cache Hit Rate"
                    value={`${(performanceMetrics.cacheHitRate * 100).toFixed(1)}%`}
                  />
                  <StatItem
                    label="Error Rate"
                    value={`${(performanceMetrics.errorRate * 100).toFixed(2)}%`}
                  />
                </>
              )}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

interface MetricCardProps {
  title: string;
  value: string | number;
  suffix?: string;
  icon: React.ElementType;
  color: 'blue' | 'green' | 'purple' | 'orange';
  trend?: {
    value: number;
    isPositive: boolean;
  };
}

function MetricCard({ title, value, suffix, icon: Icon, color, trend }: MetricCardProps) {
  const colorClasses = {
    blue: 'bg-blue-100 text-blue-600',
    green: 'bg-green-100 text-green-600',
    purple: 'bg-purple-100 text-purple-600',
    orange: 'bg-orange-100 text-orange-600',
  };

  return (
    <div className="rounded-lg bg-white p-6 shadow-sm">
      <div className="flex items-center justify-between">
        <div className={`rounded-lg p-3 ${colorClasses[color]}`}>
          <Icon className="h-6 w-6" />
        </div>
        {trend && (
          <div
            className={`text-sm font-medium ${trend.isPositive ? 'text-green-600' : 'text-red-600'}`}
          >
            {trend.isPositive ? '+' : '-'}
            {trend.value}%
          </div>
        )}
      </div>
      <div className="mt-4">
        <p className="text-sm font-medium text-gray-500">{title}</p>
        <p className="mt-2 flex items-baseline gap-1">
          <span className="text-3xl font-bold text-gray-900">{value}</span>
          {suffix && <span className="text-sm text-gray-500">{suffix}</span>}
        </p>
      </div>
    </div>
  );
}

interface StatItemProps {
  label: string;
  value: string | number;
}

function StatItem({ label, value }: StatItemProps) {
  return (
    <div className="rounded-lg border border-gray-200 p-4">
      <p className="text-sm text-gray-500">{label}</p>
      <p className="mt-1 text-2xl font-semibold text-gray-900">{value}</p>
    </div>
  );
}
