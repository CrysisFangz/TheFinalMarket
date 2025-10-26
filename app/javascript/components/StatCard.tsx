import React, { useState, useEffect, useCallback, useMemo } from 'react';

// Type definitions for TypeScript
interface TrendAnalysis {
  direction: 'positive' | 'negative' | 'neutral';
  percentage: number;
  text: string;
  icon?: string;
  significant: boolean;
  strength: number;
  label: string;
}

interface StatCardProps {
  statType: string;
  iconSvg?: string;
  value: string | number;
  label: string;
  change?: number;
  link?: string;
  linkText?: string;
  context?: Record<string, any>;
  interactive?: boolean;
}

// Utility functions
const formatValue = (value: string | number, statType: string): string => {
  const numValue = typeof value === 'string' ? parseFloat(value) : value;

  if (isNaN(numValue)) return value.toString();

  if (Math.abs(numValue) >= 1000000) {
    return (numValue / 1000000).toFixed(1) + 'M';
  } else if (Math.abs(numValue) >= 1000) {
    return (numValue / 1000).toFixed(1) + 'K';
  }

  return numValue.toFixed(0);
};

const getTrendColor = (direction: string): string => {
  const colors: Record<string, string> = {
    positive: 'text-green-600 bg-green-100',
    negative: 'text-red-600 bg-red-100',
    neutral: 'text-gray-600 bg-gray-100',
  };
  return colors[direction] || colors.neutral;
};

const getStatIcon = (statType: string): string => {
  const icons: Record<string, string> = {
    revenue: '💰',
    sales: '📈',
    users: '👥',
    orders: '📦',
    conversion: '🎯',
    growth: '📈',
    default: '📊',
  };
  return icons[statType] || icons.default;
};

// Presentation component
const StatCard: React.FC<StatCardProps> = React.memo(({
  statType,
  iconSvg,
  value,
  label,
  change,
  link,
  linkText = 'View →',
  context = {},
  interactive = true
}) => {
  const [detailsLoaded, setDetailsLoaded] = useState(false);
  const [detailedData, setDetailedData] = useState<any>(null);
  const [interactionCount, setInteractionCount] = useState(0);
  const [insightsVisible, setInsightsVisible] = useState(false);

  // Memoized trend analysis
  const trendAnalysis: TrendAnalysis = useMemo(() => {
    if (!change) {
      return {
        direction: 'neutral',
        percentage: 0,
        text: 'No change',
        significant: false,
        strength: 0,
        label: 'Stable'
      };
    }

    const percentage = Math.abs(change);
    const direction = change > 0 ? 'positive' : change < 0 ? 'negative' : 'neutral';
    const significant = percentage > 5;

    return {
      direction,
      percentage,
      text: `${direction === 'positive' ? '+' : ''}${percentage}%`,
      icon: direction === 'positive' ? '↗' : direction === 'negative' ? '↘' : '→',
      significant,
      strength: percentage,
      label: significant ? `${direction} trend` : 'stable'
    };
  }, [change]);

  // Load detailed analytics
  const loadDetailedAnalytics = useCallback(async () => {
    if (detailsLoaded) return;

    try {
      // Mock API call - in real implementation this would fetch from backend
      const mockData = {
        previous_period: typeof value === 'number' ? value * 0.9 : parseFloat(value.toString()) * 0.9,
        period_over_period: change || 0,
        trend_analysis: Array.from({ length: 7 }, (_, i) => ({
          date: new Date(Date.now() - (6 - i) * 24 * 60 * 60 * 1000).toLocaleDateString(),
          value: typeof value === 'number' ? value + (Math.random() - 0.5) * value * 0.1 : parseFloat(value.toString()) + (Math.random() - 0.5) * parseFloat(value.toString()) * 0.1
        })),
        insights: [
          {
            icon: '💡',
            title: 'Performance Insight',
            description: `This ${statType} metric shows ${trendAnalysis.direction} movement.`
          }
        ]
      };

      setDetailedData(mockData);
      setDetailsLoaded(true);

      // Cache the results
      const cacheKey = `stat-details-${statType}-${value}`;
      sessionStorage.setItem(cacheKey, JSON.stringify(mockData));
    } catch (error) {
      console.error('Failed to load detailed analytics:', error);
      setDetailedData({ error: 'Unable to load detailed analytics' });
    }
  }, [detailsLoaded, statType, value, change, trendAnalysis]);

  // Show details
  const showDetails = useCallback(async () => {
    setInteractionCount(prev => prev + 1);

    if (!detailsLoaded) {
      await loadDetailedAnalytics();
    }

    // In a real implementation, this would show a modal or navigate to details page
    console.log('Showing stat details for:', statType, detailedData);
  }, [detailsLoaded, loadDetailedAnalytics, statType, detailedData]);

  // Toggle insights
  const toggleInsights = useCallback(() => {
    setInsightsVisible(prev => !prev);
  }, []);

  // Keyboard navigation
  const handleKeyDown = useCallback((e: React.KeyboardEvent) => {
    switch (e.key) {
      case 'Enter':
      case ' ':
        e.preventDefault();
        showDetails();
        break;
      case 'Escape':
        if (insightsVisible) {
          e.preventDefault();
          setInsightsVisible(false);
        }
        break;
    }
  }, [showDetails, insightsVisible]);

  // Preload details for interactive cards
  useEffect(() => {
    if (shouldPreload()) {
      loadDetailedAnalytics();
    }
  }, [loadDetailedAnalytics]);

  const shouldPreload = (): boolean => {
    return interactionCount > 0 ||
           trendAnalysis.significant ||
           (context.priority === 'critical');
  };

  const formattedValue = formatValue(value, statType);

  if (!interactive) {
    return (
      <div className={`flex items-center space-x-3 p-4 rounded-lg border ${trendAnalysis.significant ? getTrendColor(trendAnalysis.direction) : 'bg-gray-50 border-gray-200'}`}>
        {iconSvg ? (
          <div dangerouslySetInnerHTML={{ __html: iconSvg }} className="w-8 h-8" />
        ) : (
          <span className="text-2xl">{getStatIcon(statType)}</span>
        )}
        <div className="flex-1">
          <div className="text-2xl font-bold text-gray-900">{formattedValue}</div>
          <div className="text-sm text-gray-600">{label}</div>
          {trendAnalysis.significant && (
            <div className={`text-sm font-medium ${getTrendColor(trendAnalysis.direction)}`}>
              {trendAnalysis.text}
            </div>
          )}
        </div>
      </div>
    );
  }

  return (
    <div
      className={`group relative flex items-center space-x-4 p-6 rounded-xl cursor-pointer transition-all duration-300 hover:shadow-lg focus:outline-none focus:ring-2 focus:ring-blue-500 border-2 ${
        trendAnalysis.significant
          ? `border-current ${getTrendColor(trendAnalysis.direction)}`
          : 'border-gray-200 bg-white hover:border-gray-300'
      }`}
      role="region"
      aria-label={`Statistic: ${label}`}
      onClick={showDetails}
      onKeyDown={handleKeyDown}
      tabIndex={0}
    >
      {/* Icon container */}
      <div className="relative flex items-center justify-center w-12 h-12 rounded-lg bg-gray-100 group-hover:bg-gray-200 transition-colors">
        {iconSvg ? (
          <div dangerouslySetInnerHTML={{ __html: iconSvg }} className="w-6 h-6" />
        ) : (
          <span className="text-xl">{getStatIcon(statType)}</span>
        )}

        {/* Trend indicator */}
        {trendAnalysis.significant && (
          <div className={`absolute -top-1 -right-1 w-5 h-5 rounded-full flex items-center justify-center text-xs ${getTrendColor(trendAnalysis.direction)}`}>
            {trendAnalysis.icon}
          </div>
        )}
      </div>

      {/* Content */}
      <div className="flex-1 min-w-0">
        {/* Value with animated counter */}
        <div className="text-3xl font-bold text-gray-900 font-mono mb-1">
          {formattedValue}
        </div>

        {/* Label */}
        <div className="flex items-center space-x-2 mb-2">
          <h3 className="text-sm font-medium text-gray-600">{label}</h3>
          {context.priority === 'critical' && (
            <span className="text-yellow-500" aria-label="High priority metric">★</span>
          )}
        </div>

        {/* Trend analysis */}
        {trendAnalysis.significant && (
          <div className={`inline-flex items-center space-x-1 px-2 py-1 rounded-full text-xs font-semibold ${getTrendColor(trendAnalysis.direction)}`}>
            {trendAnalysis.icon && <span>{trendAnalysis.icon}</span>}
            <span>{trendAnalysis.text}</span>
          </div>
        )}

        {/* Insights */}
        {context.insights_enabled !== false && detailedData?.insights && (
          <div className="mt-3">
            <button
              className="text-sm text-blue-600 hover:text-blue-800 focus:outline-none focus:ring-2 focus:ring-blue-500 rounded"
              onClick={(e) => {
                e.stopPropagation();
                toggleInsights();
              }}
              aria-expanded={insightsVisible}
            >
              💡 {detailedData.insights.length} insight{detailedData.insights.length !== 1 ? 's' : ''}
            </button>

            {insightsVisible && (
              <div className="mt-2 p-3 bg-gray-50 rounded-lg">
                {detailedData.insights.slice(0, 2).map((insight: any, index: number) => (
                  <div key={index} className="flex items-start space-x-2 mb-2 last:mb-0">
                    <span className="text-yellow-500 mt-1">{insight.icon}</span>
                    <div>
                      <div className="text-sm font-medium text-gray-900">{insight.title}</div>
                      <div className="text-sm text-gray-600">{insight.description}</div>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        )}

        {/* Metadata */}
        <div className="flex items-center justify-between mt-3 text-xs text-gray-500">
          <span>Updated {new Date().toLocaleDateString()}</span>
          {context.data_freshness && (
            <span className={`px-2 py-1 rounded-full text-xs font-medium ${
              context.data_freshness === 'realtime' ? 'bg-green-100 text-green-800' :
              context.data_freshness === 'live' ? 'bg-blue-100 text-blue-800' :
              'bg-yellow-100 text-yellow-800'
            }`}>
              {context.data_freshness} data
            </span>
          )}
        </div>
      </div>

      {/* Action link */}
      {link && (
        <a
          href={link}
          className="absolute top-4 right-4 px-3 py-1 bg-white bg-opacity-80 text-gray-700 border border-gray-300 rounded-lg text-sm font-medium opacity-0 group-hover:opacity-100 transition-all duration-200 hover:bg-opacity-100"
          aria-label={`${label} - ${linkText}`}
          onClick={(e) => e.stopPropagation()}
        >
          {linkText}
        </a>
      )}

      {/* Hover indicator */}
      <div className="absolute inset-0 rounded-xl opacity-0 group-hover:opacity-100 transition-opacity duration-200 pointer-events-none">
        <div className="absolute inset-0 bg-gradient-radial from-white via-transparent to-transparent opacity-10 rounded-xl"></div>
      </div>
    </div>
  );
});

export default StatCard;