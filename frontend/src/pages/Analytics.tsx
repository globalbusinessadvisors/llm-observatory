import { useEffect, useState } from 'react'
import { useAnalyticsStore } from '../store/analyticsStore'
import { CostChart } from '../components/charts/CostChart'
import { ModelUsageChart } from '../components/charts/ModelUsageChart'
import { TokenUsageChart } from '../components/charts/TokenUsageChart'
import { CostDisplay } from '../components/CostDisplay'
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '../components/ui/Card'
import { Button } from '../components/ui/Button'
import { Calendar, Download, RefreshCw, TrendingUp, Activity } from 'lucide-react'

export function Analytics() {
  const {
    data,
    isLoading,
    dateRange,
    setDateRange,
    refreshAnalytics
  } = useAnalyticsStore()

  const [selectedRange, setSelectedRange] = useState<'7d' | '30d' | '90d'>('30d')

  useEffect(() => {
    refreshAnalytics()
  }, [refreshAnalytics])

  const handleDateRangeChange = (range: '7d' | '30d' | '90d') => {
    setSelectedRange(range)
    const end = new Date()
    const start = new Date()

    switch (range) {
      case '7d':
        start.setDate(start.getDate() - 7)
        break
      case '30d':
        start.setDate(start.getDate() - 30)
        break
      case '90d':
        start.setDate(start.getDate() - 90)
        break
    }

    setDateRange(start, end)
  }

  const handleExport = () => {
    if (!data) return

    const exportData = {
      date_range: dateRange,
      analytics: data,
      exported_at: new Date().toISOString()
    }

    const blob = new Blob([JSON.stringify(exportData, null, 2)], {
      type: 'application/json'
    })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `analytics-${new Date().toISOString().split('T')[0]}.json`
    document.body.appendChild(a)
    a.click()
    document.body.removeChild(a)
    URL.revokeObjectURL(url)
  }

  return (
    <div className="min-h-screen bg-background">
      {/* Header */}
      <div className="border-b border-border bg-card">
        <div className="container mx-auto px-6 py-6">
          <div className="flex items-center justify-between mb-4">
            <div>
              <h1 className="text-3xl font-bold mb-2">Analytics Dashboard</h1>
              <p className="text-muted-foreground">
                Comprehensive insights into your AI customer support performance
              </p>
            </div>
            <div className="flex gap-2">
              <Button
                onClick={handleExport}
                variant="outline"
                disabled={!data}
              >
                <Download className="mr-2" size={18} />
                Export
              </Button>
              <Button
                onClick={refreshAnalytics}
                disabled={isLoading}
                variant="outline"
              >
                <RefreshCw className={`mr-2 ${isLoading ? 'animate-spin' : ''}`} size={18} />
                Refresh
              </Button>
            </div>
          </div>

          {/* Date Range Selector */}
          <div className="flex items-center gap-2">
            <Calendar className="text-muted-foreground" size={18} />
            <span className="text-sm text-muted-foreground mr-2">Date Range:</span>
            <div className="flex gap-2">
              {(['7d', '30d', '90d'] as const).map((range) => (
                <Button
                  key={range}
                  variant={selectedRange === range ? 'default' : 'outline'}
                  size="sm"
                  onClick={() => handleDateRangeChange(range)}
                >
                  Last {range}
                </Button>
              ))}
            </div>
          </div>
        </div>
      </div>

      <div className="container mx-auto px-6 py-6">
        {/* Key Metrics */}
        <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-4 mb-6">
          <CostDisplay
            cost={data?.total_cost || 0}
            label="Total Cost"
          />

          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">Conversations</CardTitle>
              <TrendingUp className="h-4 w-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">{data?.total_conversations || 0}</div>
              <p className="text-xs text-muted-foreground mt-1">
                {data?.active_conversations || 0} active
              </p>
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">Avg. Tokens</CardTitle>
              <Activity className="h-4 w-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">
                {Math.round(data?.average_tokens_per_message || 0)}
              </div>
              <p className="text-xs text-muted-foreground mt-1">
                per message
              </p>
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">Success Rate</CardTitle>
              <Activity className="h-4 w-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold text-green-600">
                {data?.feedback_summary?.positive_percentage?.toFixed(1) || 0}%
              </div>
              <p className="text-xs text-muted-foreground mt-1">
                positive feedback
              </p>
            </CardContent>
          </Card>
        </div>

        {/* Charts */}
        <div className="grid gap-6 lg:grid-cols-2 mb-6">
          {data?.cost_over_time && data.cost_over_time.length > 0 && (
            <CostChart data={data.cost_over_time} />
          )}

          {data?.cost_over_time && data.cost_over_time.length > 0 && (
            <TokenUsageChart data={data.cost_over_time} />
          )}
        </div>

        {/* Model Usage */}
        {data?.model_usage && data.model_usage.length > 0 && (
          <div className="grid gap-6 lg:grid-cols-3 mb-6">
            <div className="lg:col-span-2">
              <ModelUsageChart data={data.model_usage} />
            </div>

            <Card>
              <CardHeader>
                <CardTitle>Model Breakdown</CardTitle>
                <CardDescription>
                  Detailed usage by model
                </CardDescription>
              </CardHeader>
              <CardContent>
                <div className="space-y-4">
                  {data.model_usage.map((model, index) => (
                    <div key={index} className="space-y-2">
                      <div className="flex items-center justify-between text-sm">
                        <span className="font-medium">{model.model}</span>
                        <span className="text-muted-foreground">
                          {model.count} requests
                        </span>
                      </div>
                      <div className="flex items-center justify-between text-xs text-muted-foreground">
                        <span>${model.total_cost.toFixed(4)} total</span>
                        <span>{Math.round(model.average_latency_ms)}ms avg</span>
                      </div>
                      {index < data.model_usage.length - 1 && (
                        <div className="border-b border-border pt-2" />
                      )}
                    </div>
                  ))}
                </div>
              </CardContent>
            </Card>
          </div>
        )}

        {/* Detailed Stats */}
        <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
          <Card>
            <CardHeader>
              <CardTitle>Cost Efficiency</CardTitle>
              <CardDescription>Average costs</CardDescription>
            </CardHeader>
            <CardContent className="space-y-3">
              <div className="flex justify-between items-center">
                <span className="text-sm text-muted-foreground">Per Conversation</span>
                <span className="font-medium">
                  ${(data?.average_cost_per_conversation || 0).toFixed(4)}
                </span>
              </div>
              <div className="flex justify-between items-center">
                <span className="text-sm text-muted-foreground">Per Message</span>
                <span className="font-medium">
                  ${data?.total_messages ? (data.total_cost / data.total_messages).toFixed(4) : '0.0000'}
                </span>
              </div>
              <div className="flex justify-between items-center">
                <span className="text-sm text-muted-foreground">Total Spend</span>
                <span className="font-bold text-lg text-primary">
                  ${(data?.total_cost || 0).toFixed(2)}
                </span>
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle>Performance Metrics</CardTitle>
              <CardDescription>Response statistics</CardDescription>
            </CardHeader>
            <CardContent className="space-y-3">
              <div className="flex justify-between items-center">
                <span className="text-sm text-muted-foreground">Avg. Latency</span>
                <span className="font-medium">
                  {Math.round(data?.average_latency_ms || 0)}ms
                </span>
              </div>
              <div className="flex justify-between items-center">
                <span className="text-sm text-muted-foreground">Total Messages</span>
                <span className="font-medium">
                  {data?.total_messages || 0}
                </span>
              </div>
              <div className="flex justify-between items-center">
                <span className="text-sm text-muted-foreground">Avg. Tokens/Message</span>
                <span className="font-medium">
                  {Math.round(data?.average_tokens_per_message || 0)}
                </span>
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle>Feedback Metrics</CardTitle>
              <CardDescription>Customer satisfaction</CardDescription>
            </CardHeader>
            <CardContent className="space-y-3">
              <div className="flex justify-between items-center">
                <span className="text-sm text-muted-foreground">Positive</span>
                <span className="font-medium text-green-600">
                  {data?.feedback_summary?.positive || 0}
                </span>
              </div>
              <div className="flex justify-between items-center">
                <span className="text-sm text-muted-foreground">Negative</span>
                <span className="font-medium text-red-600">
                  {data?.feedback_summary?.negative || 0}
                </span>
              </div>
              <div className="flex justify-between items-center">
                <span className="text-sm text-muted-foreground">Success Rate</span>
                <span className="font-bold text-lg text-green-600">
                  {data?.feedback_summary?.positive_percentage?.toFixed(1) || 0}%
                </span>
              </div>
            </CardContent>
          </Card>
        </div>

        {/* Empty State */}
        {!isLoading && !data && (
          <Card className="p-12 text-center">
            <Activity className="mx-auto mb-4 text-muted-foreground" size={64} />
            <h3 className="text-xl font-semibold mb-2">No Data Available</h3>
            <p className="text-muted-foreground mb-4">
              Start using the AI customer support to see analytics here
            </p>
          </Card>
        )}
      </div>
    </div>
  )
}
