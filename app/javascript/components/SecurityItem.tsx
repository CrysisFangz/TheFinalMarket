import React, { useState, useEffect, useCallback, useMemo } from 'react';

// Type definitions for TypeScript
interface SecurityStatus {
  score: number;
  level: 'optimal' | 'enhanced' | 'standard' | 'at_risk' | 'critical' | 'unknown';
  label: string;
  description: string;
  compliance?: string[];
  recommendations?: string[];
  last_assessed?: string;
}

interface SecurityItemProps {
  type: string;
  user?: any;
  icon?: React.ReactNode;
  text: string;
  context?: Record<string, any>;
  showTooltip?: boolean;
  interactive?: boolean;
}

// Utility functions
const getStatusColor = (level: string): string => {
  const colors: Record<string, string> = {
    optimal: 'bg-green-100 text-green-800 border-green-200',
    enhanced: 'bg-blue-100 text-blue-800 border-blue-200',
    standard: 'bg-yellow-100 text-yellow-800 border-yellow-200',
    at_risk: 'bg-orange-100 text-orange-800 border-orange-200',
    critical: 'bg-red-100 text-red-800 border-red-200',
    unknown: 'bg-gray-100 text-gray-800 border-gray-200',
  };
  return colors[level] || colors.unknown;
};

const getStatusIcon = (level: string): string => {
  const icons: Record<string, string> = {
    optimal: '🛡️',
    enhanced: '🔒',
    standard: '⚠️',
    at_risk: '🚨',
    critical: '🔴',
    unknown: '❓',
  };
  return icons[level] || icons.unknown;
};

// Presentation component
const SecurityItem: React.FC<SecurityItemProps> = React.memo(({
  type,
  user,
  icon,
  text,
  context = {},
  showTooltip = true,
  interactive = true
}) => {
  const [recommendationsExpanded, setRecommendationsExpanded] = useState(false);
  const [detailsLoaded, setDetailsLoaded] = useState(false);
  const [securityDetails, setSecurityDetails] = useState<any>(null);
  const [interactionCount, setInteractionCount] = useState(0);

  // Memoized security assessment
  const securityStatus: SecurityStatus = useMemo(() => {
    // This would typically come from a security assessment service
    // For now, using mock data based on type
    const mockStatuses: Record<string, SecurityStatus> = {
      email_verified: {
        score: 95,
        level: 'optimal',
        label: 'Verified',
        description: 'Your email address has been verified successfully.',
        compliance: ['GDPR', 'SOX'],
        last_assessed: new Date().toISOString()
      },
      two_factor_enabled: {
        score: 90,
        level: 'enhanced',
        label: 'Protected',
        description: 'Two-factor authentication is enabled for additional security.',
        compliance: ['NIST', 'ISO27001'],
        last_assessed: new Date().toISOString()
      },
      strong_password: {
        score: 85,
        level: 'standard',
        label: 'Good',
        description: 'Your password meets security requirements.',
        compliance: ['OWASP'],
        last_assessed: new Date().toISOString()
      }
    };

    return mockStatuses[type] || {
      score: 0,
      level: 'unknown',
      label: 'Unknown',
      description: 'Security status could not be determined.',
      last_assessed: new Date().toISOString()
    };
  }, [type, user, context]);

  // Load security details
  const loadSecurityDetails = useCallback(async () => {
    if (detailsLoaded) return;

    try {
      // Mock API call - in real implementation this would fetch from backend
      const details = {
        title: `${text} Security Details`,
        recommendations: securityStatus.recommendations || [],
        compliance: securityStatus.compliance || [],
        score_breakdown: {
          strength: securityStatus.score,
          compliance: 95,
          monitoring: 88
        }
      };

      setSecurityDetails(details);
      setDetailsLoaded(true);

      // Cache the results
      sessionStorage.setItem(`security-details-${type}-${securityStatus.score}`, JSON.stringify(details));
    } catch (error) {
      console.error('Failed to load security details:', error);
      setSecurityDetails({ error: 'Unable to load security details' });
    }
  }, [detailsLoaded, type, securityStatus, text]);

  // Show security details
  const showDetails = useCallback(async () => {
    setInteractionCount(prev => prev + 1);

    if (!detailsLoaded) {
      await loadSecurityDetails();
    }

    // In a real implementation, this would show a modal or navigate to details page
    console.log('Showing security details for:', type, securityDetails);
  }, [detailsLoaded, loadSecurityDetails, type, securityDetails]);

  // Toggle recommendations
  const toggleRecommendations = useCallback(() => {
    setRecommendationsExpanded(prev => !prev);
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
        if (recommendationsExpanded) {
          e.preventDefault();
          setRecommendationsExpanded(false);
        }
        break;
    }
  }, [showDetails, recommendationsExpanded]);

  // Preload details for critical items
  useEffect(() => {
    if (shouldPreload()) {
      loadSecurityDetails();
    }
  }, [loadSecurityDetails]);

  const shouldPreload = (): boolean => {
    return interactionCount > 0 ||
           securityStatus.level === 'critical' ||
           securityStatus.level === 'at_risk';
  };

  if (!interactive) {
    return (
      <div className={`flex items-center space-x-3 p-3 rounded-lg border ${getStatusColor(securityStatus.level)}`}>
        {icon || <span className="text-lg">{getStatusIcon(securityStatus.level)}</span>}
        <div className="flex-1">
          <div className="font-medium">{text}</div>
          <div className="text-sm opacity-75">{securityStatus.label}</div>
        </div>
        <div className="text-sm font-semibold">{securityStatus.score}%</div>
      </div>
    );
  }

  return (
    <div
      className={`group relative flex items-center space-x-3 p-4 rounded-lg border-2 cursor-pointer transition-all duration-300 hover:shadow-lg focus:outline-none focus:ring-2 focus:ring-blue-500 ${getStatusColor(securityStatus.level)}`}
      role="button"
      tabIndex={0}
      aria-label={`${text} - ${securityStatus.label} - Score: ${securityStatus.score}%`}
      onClick={showDetails}
      onKeyDown={handleKeyDown}
    >
      {/* Visual container */}
      <div className="relative flex items-center justify-center w-12 h-12">
        {icon || <span className="text-xl">{getStatusIcon(securityStatus.level)}</span>}

        {/* Score indicator */}
        <div className="absolute -bottom-1 -right-1 w-6 h-6 bg-black bg-opacity-70 rounded-full flex items-center justify-center text-xs font-bold text-white">
          {securityStatus.score}
        </div>
      </div>

      {/* Content */}
      <div className="flex-1 min-w-0">
        <div className="flex items-center space-x-2">
          <h3 className="font-semibold text-gray-900">{text}</h3>
          {securityStatus.level === 'critical' && (
            <span className="text-red-500 animate-bounce" aria-label="Critical security issue">⚠️</span>
          )}
        </div>

        <p className="text-sm text-gray-600 mt-1">
          {securityStatus.description.length > 120
            ? `${securityStatus.description.substring(0, 120)}...`
            : securityStatus.description
          }
        </p>

        {/* Compliance badges */}
        {securityStatus.compliance && securityStatus.compliance.length > 0 && (
          <div className="flex flex-wrap gap-1 mt-2" role="list" aria-label="Compliance certifications">
            {securityStatus.compliance.slice(0, 3).map((badge, index) => (
              <span
                key={index}
                className="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-white bg-opacity-50"
                role="listitem"
                aria-label={`${badge} compliant`}
              >
                {badge}
              </span>
            ))}
            {securityStatus.compliance.length > 3 && (
              <span className="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-gray-200 text-gray-600">
                +{securityStatus.compliance.length - 3}
              </span>
            )}
          </div>
        )}

        {/* Recommendations */}
        {securityStatus.recommendations && securityStatus.recommendations.length > 0 && securityStatus.level !== 'optimal' && (
          <div className="mt-3">
            <button
              className="text-sm text-blue-600 hover:text-blue-800 focus:outline-none focus:ring-2 focus:ring-blue-500 rounded"
              onClick={(e) => {
                e.stopPropagation();
                toggleRecommendations();
              }}
              aria-expanded={recommendationsExpanded}
            >
              💡 {securityStatus.recommendations.length} suggestion{securityStatus.recommendations.length !== 1 ? 's' : ''}
            </button>

            {recommendationsExpanded && (
              <div className="mt-2 p-3 bg-white bg-opacity-70 rounded-lg backdrop-blur-sm">
                {securityStatus.recommendations.map((recommendation, index) => (
                  <div
                    key={index}
                    className="text-sm text-gray-700 mb-2 last:mb-0 flex items-start space-x-2"
                    style={{ animationDelay: `${index * 0.1}s` }}
                  >
                    <span className="text-blue-500 mt-1">→</span>
                    <span>{recommendation}</span>
                  </div>
                ))}
              </div>
            )}
          </div>
        )}

        {/* Last assessed */}
        {securityStatus.last_assessed && (
          <div className="text-xs text-gray-500 mt-2">
            Updated {new Date(securityStatus.last_assessed).toLocaleDateString()}
          </div>
        )}
      </div>

      {/* Hover indicator */}
      <div className="absolute inset-0 rounded-lg opacity-0 group-hover:opacity-100 transition-opacity duration-200 pointer-events-none">
        <div className="absolute inset-0 bg-gradient-radial from-white via-transparent to-transparent opacity-10 rounded-lg"></div>
      </div>
    </div>
  );
});

export default SecurityItem;