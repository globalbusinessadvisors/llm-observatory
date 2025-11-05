import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  Legend,
  Cell
} from 'recharts'
import { ModelUsage } from '../../types'
import { Card, CardContent, CardHeader, CardTitle } from '../ui/Card'

interface ModelUsageChartProps {
  data: ModelUsage[]
  className?: string
}

const COLORS = [
  'hsl(221.2 83.2% 53.3%)', // primary
  'hsl(217.2 91.2% 59.8%)', // blue
  'hsl(142.1 76.2% 36.3%)', // green
  'hsl(24.6 95% 53.1%)',    // orange
  'hsl(262.1 83.3% 57.8%)', // purple
]

export function ModelUsageChart({ data, className }: ModelUsageChartProps) {
  const formattedData = data.map((item) => ({
    ...item,
    cost: parseFloat(item.total_cost.toFixed(4))
  }))

  return (
    <Card className={className}>
      <CardHeader>
        <CardTitle>Model Usage</CardTitle>
      </CardHeader>
      <CardContent>
        <ResponsiveContainer width="100%" height={300}>
          <BarChart data={formattedData}>
            <CartesianGrid strokeDasharray="3 3" className="stroke-muted" />
            <XAxis
              dataKey="model"
              className="text-xs"
              tick={{ fill: 'hsl(var(--muted-foreground))' }}
            />
            <YAxis
              className="text-xs"
              tick={{ fill: 'hsl(var(--muted-foreground))' }}
              tickFormatter={(value) => `$${value}`}
            />
            <Tooltip
              contentStyle={{
                backgroundColor: 'hsl(var(--card))',
                border: '1px solid hsl(var(--border))',
                borderRadius: '8px'
              }}
              formatter={(value: number, name: string) => {
                if (name === 'cost') return [`$${value.toFixed(4)}`, 'Total Cost']
                return [value, name]
              }}
            />
            <Legend />
            <Bar dataKey="cost" name="Cost" radius={[8, 8, 0, 0]}>
              {formattedData.map((entry, index) => (
                <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
              ))}
            </Bar>
          </BarChart>
        </ResponsiveContainer>
      </CardContent>
    </Card>
  )
}
