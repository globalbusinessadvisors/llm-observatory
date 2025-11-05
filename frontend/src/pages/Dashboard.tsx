import { useEffect } from 'react'
import { useChatStore } from '../store/chatStore'
import { useAnalyticsStore } from '../store/analyticsStore'
import { ConversationList } from '../components/ConversationList'
import { CostDisplay, CostBreakdown } from '../components/CostDisplay'
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '../components/ui/Card'
import { Button } from '../components/ui/Button'
import {
  MessageSquare,
  TrendingUp,
  Clock,
  ThumbsUp,
  RefreshCw,
  Users
} from 'lucide-react'
import { formatTokenCount } from '../lib/utils'

export function Dashboard() {
  const {
    conversations,
    fetchConversations,
    setCurrentConversation,
    isLoading: chatLoading
  } = useChatStore()

  const {
    data: analytics,
    isLoading: analyticsLoading,
    fetchAnalytics,
    refreshAnalytics
  } = useAnalyticsStore()

  useEffect(() => {
    fetchConversations()
    fetchAnalytics()
  }, [fetchConversations, fetchAnalytics])

  const activeConversations = conversations.filter((c) => c.status === 'active')
  const isLoading = chatLoading || analyticsLoading

  const stats = [
    {
      title: 'Total Conversations',
      value: analytics?.total_conversations || 0,
      icon: MessageSquare,
      description: `${activeConversations.length} active`
    },
    {
      title: 'Total Messages',
      value: analytics?.total_messages || 0,
      icon: MessageSquare,
      description: 'All time'
    },
    {
      title: 'Avg. Cost/Conv.',
      value: `$${(analytics?.average_cost_per_conversation || 0).toFixed(4)}`,
      icon: TrendingUp,
      description: 'Per conversation'
    },
    {
      title: 'Avg. Latency',
      value: `${Math.round(analytics?.average_latency_ms || 0)}ms`,
      icon: Clock,
      description: 'Response time'
    }
  ]

  return (
    <div className="min-h-screen bg-background">
      {/* Header */}
      <div className="border-b border-border bg-card">
        <div className="container mx-auto px-6 py-6">
          <div className="flex items-center justify-between">
            <div>
              <h1 className="text-3xl font-bold mb-2">Agent Dashboard</h1>
              <p className="text-muted-foreground">
                Monitor and manage customer support conversations
              </p>
            </div>
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
      </div>

      <div className="container mx-auto px-6 py-6">
        {/* Stats Grid */}
        <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-4 mb-6">
          {stats.map((stat, index) => (
            <Card key={index}>
              <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                <CardTitle className="text-sm font-medium">{stat.title}</CardTitle>
                <stat.icon className="h-4 w-4 text-muted-foreground" />
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold">{stat.value}</div>
                <p className="text-xs text-muted-foreground mt-1">
                  {stat.description}
                </p>
              </CardContent>
            </Card>
          ))}
        </div>

        {/* Main Content Grid */}
        <div className="grid gap-6 lg:grid-cols-3">
          {/* Left Column - 2/3 width */}
          <div className="lg:col-span-2 space-y-6">
            {/* Cost Overview */}
            <div className="grid gap-6 md:grid-cols-2">
              <CostDisplay
                cost={analytics?.total_cost || 0}
                tokens={analytics?.total_messages ?
                  (analytics.average_tokens_per_message * analytics.total_messages) : 0}
                label="Total Cost"
              />

              {analytics?.model_usage && analytics.model_usage.length > 0 && (
                <CostBreakdown
                  items={analytics.model_usage.map((model) => ({
                    label: model.model,
                    cost: model.total_cost
                  }))}
                />
              )}
            </div>

            {/* Feedback Summary */}
            {analytics?.feedback_summary && (
              <Card>
                <CardHeader>
                  <CardTitle>Feedback Summary</CardTitle>
                  <CardDescription>
                    Customer satisfaction metrics
                  </CardDescription>
                </CardHeader>
                <CardContent>
                  <div className="space-y-4">
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-2">
                        <ThumbsUp className="text-green-600" size={20} />
                        <span className="text-sm font-medium">Positive Feedback</span>
                      </div>
                      <div className="text-right">
                        <div className="text-2xl font-bold text-green-600">
                          {analytics.feedback_summary.positive_percentage.toFixed(1)}%
                        </div>
                        <div className="text-xs text-muted-foreground">
                          {analytics.feedback_summary.positive} of {analytics.feedback_summary.total}
                        </div>
                      </div>
                    </div>

                    <div className="w-full bg-secondary rounded-full h-3">
                      <div
                        className="bg-green-600 h-3 rounded-full transition-all"
                        style={{
                          width: `${analytics.feedback_summary.positive_percentage}%`
                        }}
                      />
                    </div>

                    <div className="grid grid-cols-2 gap-4 pt-2">
                      <div className="text-center p-3 bg-green-50 rounded-lg">
                        <div className="text-2xl font-bold text-green-600">
                          {analytics.feedback_summary.positive}
                        </div>
                        <div className="text-xs text-muted-foreground">Positive</div>
                      </div>
                      <div className="text-center p-3 bg-red-50 rounded-lg">
                        <div className="text-2xl font-bold text-red-600">
                          {analytics.feedback_summary.negative}
                        </div>
                        <div className="text-xs text-muted-foreground">Negative</div>
                      </div>
                    </div>
                  </div>
                </CardContent>
              </Card>
            )}

            {/* Model Performance */}
            {analytics?.model_usage && analytics.model_usage.length > 0 && (
              <Card>
                <CardHeader>
                  <CardTitle>Model Performance</CardTitle>
                  <CardDescription>
                    Usage statistics by AI model
                  </CardDescription>
                </CardHeader>
                <CardContent>
                  <div className="space-y-4">
                    {analytics.model_usage.map((model, index) => (
                      <div key={index} className="flex items-center justify-between p-3 bg-muted/50 rounded-lg">
                        <div>
                          <div className="font-medium">{model.model}</div>
                          <div className="text-sm text-muted-foreground">
                            {model.count} requests • {Math.round(model.average_latency_ms)}ms avg
                          </div>
                        </div>
                        <div className="text-right">
                          <div className="font-bold">${model.total_cost.toFixed(4)}</div>
                          <div className="text-xs text-muted-foreground">total cost</div>
                        </div>
                      </div>
                    ))}
                  </div>
                </CardContent>
              </Card>
            )}
          </div>

          {/* Right Column - 1/3 width */}
          <div className="space-y-6">
            {/* Active Conversations */}
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center gap-2">
                  <Users size={18} />
                  Active Conversations
                </CardTitle>
                <CardDescription>
                  {activeConversations.length} conversations need attention
                </CardDescription>
              </CardHeader>
              <CardContent className="p-0">
                <div className="max-h-[600px] overflow-y-auto px-6 pb-6">
                  <ConversationList
                    conversations={activeConversations.slice(0, 10)}
                    currentConversationId={null}
                    onSelectConversation={setCurrentConversation}
                  />
                </div>
              </CardContent>
            </Card>
          </div>
        </div>
      </div>
    </div>
  )
}
