import { DollarSign, TrendingUp, TrendingDown } from 'lucide-react'
import { Card, CardContent, CardHeader, CardTitle } from './ui/Card'
import { formatCost, formatTokenCount } from '../lib/utils'
import { cn } from '../lib/utils'

interface CostDisplayProps {
  cost: number
  tokens?: number
  trend?: number // percentage change
  label?: string
  className?: string
}

export function CostDisplay({
  cost,
  tokens,
  trend,
  label = 'Total Cost',
  className
}: CostDisplayProps) {
  const hasTrend = trend !== undefined
  const isPositiveTrend = trend ? trend > 0 : false

  return (
    <Card className={className}>
      <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
        <CardTitle className="text-sm font-medium">{label}</CardTitle>
        <DollarSign className="h-4 w-4 text-muted-foreground" />
      </CardHeader>
      <CardContent>
        <div className="text-2xl font-bold">{formatCost(cost)}</div>
        <div className="flex items-center gap-2 mt-1 text-xs text-muted-foreground">
          {tokens && (
            <span>{formatTokenCount(tokens)} tokens</span>
          )}
          {hasTrend && (
            <>
              {tokens && <span>•</span>}
              <div className={cn(
                'flex items-center gap-1',
                isPositiveTrend ? 'text-red-600' : 'text-green-600'
              )}>
                {isPositiveTrend ? (
                  <TrendingUp size={12} />
                ) : (
                  <TrendingDown size={12} />
                )}
                <span>{Math.abs(trend).toFixed(1)}%</span>
              </div>
            </>
          )}
        </div>
      </CardContent>
    </Card>
  )
}

interface CostBreakdownProps {
  items: Array<{
    label: string
    cost: number
    percentage?: number
  }>
  className?: string
}

export function CostBreakdown({ items, className }: CostBreakdownProps) {
  const total = items.reduce((sum, item) => sum + item.cost, 0)

  return (
    <Card className={className}>
      <CardHeader>
        <CardTitle>Cost Breakdown</CardTitle>
      </CardHeader>
      <CardContent>
        <div className="space-y-4">
          {items.map((item, index) => {
            const percentage = item.percentage ?? (total > 0 ? (item.cost / total) * 100 : 0)

            return (
              <div key={index} className="space-y-2">
                <div className="flex items-center justify-between text-sm">
                  <span className="text-muted-foreground">{item.label}</span>
                  <span className="font-medium">{formatCost(item.cost)}</span>
                </div>
                <div className="w-full bg-secondary rounded-full h-2">
                  <div
                    className="bg-primary h-2 rounded-full transition-all"
                    style={{ width: `${percentage}%` }}
                  />
                </div>
                <div className="text-xs text-muted-foreground text-right">
                  {percentage.toFixed(1)}%
                </div>
              </div>
            )
          })}
        </div>
      </CardContent>
    </Card>
  )
}
