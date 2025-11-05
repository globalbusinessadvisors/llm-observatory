import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer } from 'recharts';
import { ModelUsageStats } from '@/types';

interface ModelUsageChartProps {
  data: ModelUsageStats[];
}

export default function ModelUsageChart({ data }: ModelUsageChartProps) {
  if (data.length === 0) {
    return (
      <div className="flex h-64 items-center justify-center text-gray-500">
        No model usage data available
      </div>
    );
  }

  const formattedData = data.map((item) => ({
    name: item.modelName.split('/').pop() || item.modelName,
    requests: item.requestCount,
    tokens: Math.round(item.totalTokens / 1000), // Convert to K tokens
    cost: Number(item.totalCost.toFixed(2)),
  }));

  return (
    <ResponsiveContainer width="100%" height={300}>
      <BarChart data={formattedData}>
        <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
        <XAxis
          dataKey="name"
          tick={{ fontSize: 12, fill: '#6b7280' }}
          stroke="#e5e7eb"
        />
        <YAxis
          yAxisId="left"
          tick={{ fontSize: 12, fill: '#6b7280' }}
          stroke="#e5e7eb"
        />
        <YAxis
          yAxisId="right"
          orientation="right"
          tick={{ fontSize: 12, fill: '#6b7280' }}
          stroke="#e5e7eb"
          tickFormatter={(value) => `$${value}`}
        />
        <Tooltip
          contentStyle={{
            backgroundColor: '#fff',
            border: '1px solid #e5e7eb',
            borderRadius: '8px',
            padding: '8px 12px',
          }}
        />
        <Legend
          wrapperStyle={{ fontSize: '12px' }}
          iconType="circle"
        />
        <Bar
          yAxisId="left"
          dataKey="requests"
          fill="#3b82f6"
          radius={[8, 8, 0, 0]}
          name="Requests"
        />
        <Bar
          yAxisId="left"
          dataKey="tokens"
          fill="#10b981"
          radius={[8, 8, 0, 0]}
          name="Tokens (K)"
        />
        <Bar
          yAxisId="right"
          dataKey="cost"
          fill="#8b5cf6"
          radius={[8, 8, 0, 0]}
          name="Cost ($)"
        />
      </BarChart>
    </ResponsiveContainer>
  );
}
