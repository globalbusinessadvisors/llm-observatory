import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer } from 'recharts';
import { PerformanceMetrics } from '@/types';

interface PerformanceChartProps {
  metrics: PerformanceMetrics | null;
}

export default function PerformanceChart({ metrics }: PerformanceChartProps) {
  if (!metrics) {
    return (
      <div className="flex h-64 items-center justify-center text-gray-500">
        No performance data available
      </div>
    );
  }

  const data = [
    {
      name: 'Average',
      latency: metrics.averageLatency,
    },
    {
      name: 'P95',
      latency: metrics.p95Latency,
    },
    {
      name: 'P99',
      latency: metrics.p99Latency,
    },
  ];

  return (
    <ResponsiveContainer width="100%" height={300}>
      <BarChart data={data}>
        <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
        <XAxis
          dataKey="name"
          tick={{ fontSize: 12, fill: '#6b7280' }}
          stroke="#e5e7eb"
        />
        <YAxis
          tick={{ fontSize: 12, fill: '#6b7280' }}
          stroke="#e5e7eb"
          tickFormatter={(value) => `${value}ms`}
        />
        <Tooltip
          contentStyle={{
            backgroundColor: '#fff',
            border: '1px solid #e5e7eb',
            borderRadius: '8px',
            padding: '8px 12px',
          }}
          formatter={(value: number) => [`${value.toFixed(0)}ms`, 'Latency']}
        />
        <Legend
          wrapperStyle={{ fontSize: '12px' }}
          iconType="circle"
        />
        <Bar
          dataKey="latency"
          fill="#0ea5e9"
          radius={[8, 8, 0, 0]}
          name="Response Time"
        />
      </BarChart>
    </ResponsiveContainer>
  );
}
