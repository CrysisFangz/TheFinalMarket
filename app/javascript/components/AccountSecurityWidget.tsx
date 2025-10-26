import React from 'react';

// Type definitions for TypeScript
interface User {
  email_verified: boolean;
  two_factor_enabled: boolean;
  password_strength?: string;
}

interface SecurityItemProps {
  type: 'email_verified' | 'two_factor_enabled' | 'strong_password';
  user: User;
  icon: React.ReactNode;
  text: string;
}

interface AccountSecurityWidgetProps {
  user: User;
}

// Presentation component for individual security item
const SecurityItem: React.FC<SecurityItemProps> = React.memo(({ type, user, icon, text }) => {
  const isEnabled = user[type as keyof User] as boolean;

  return (
    <div className="flex items-center space-x-3 p-3 rounded-lg border border-gray-200 bg-white shadow-sm transition-all duration-200 hover:shadow-md focus-within:ring-2 focus-within:ring-blue-500" role="listitem" aria-label={`${text} status`}>
      <div className={`flex-shrink-0 w-8 h-8 flex items-center justify-center rounded-full ${isEnabled ? 'bg-green-100 text-green-600' : 'bg-red-100 text-red-600'}`} aria-hidden="true">
        {icon}
      </div>
      <span className={`text-sm font-medium ${isEnabled ? 'text-green-800' : 'text-red-800'}`}>
        {text}
      </span>
      <span className={`ml-auto text-xs font-semibold px-2 py-1 rounded-full ${isEnabled ? 'bg-green-200 text-green-800' : 'bg-red-200 text-red-800'}`} aria-label={isEnabled ? 'Enabled' : 'Disabled'}>
        {isEnabled ? '✓' : '✗'}
      </span>
    </div>
  );
});

// Main presentation component
const AccountSecurityWidget: React.FC<AccountSecurityWidgetProps> = React.memo(({ user }) => {
  // Icons as SVG for performance and accessibility
  const emailIcon = (
    <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 20 20" aria-hidden="true">
      <path d="M2.003 5.884L10 9.882l7.997-3.998A2 2 0 0016 4H4a2 2 0 00-1.997 1.884z" />
      <path d="M18 8.118l-8 4-8-4V14a2 2 0 002 2h12a2 2 0 002-2V8.118z" />
    </svg>
  );

  const twoFactorIcon = (
    <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 20 20" aria-hidden="true">
      <path fillRule="evenodd" d="M5 9V7a5 5 0 0110 0v2a2 2 0 012 2v5a2 2 0 01-2 2H5a2 2 0 01-2-2v-5a2 2 0 012-2zm8-2v2H7V7a3 3 0 016 0z" clipRule="evenodd" />
    </svg>
  );

  const passwordIcon = (
    <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 20 20" aria-hidden="true">
      <path fillRule="evenodd" d="M18 8a6 6 0 01-7.743 5.743L10 11.486V8a6 6 0 1112 0zM8 8a1 1 0 000 2h.01a1 1 0 100-2H8z" clipRule="evenodd" />
    </svg>
  );

  return (
    <div className="bg-gray-50 p-6 rounded-xl shadow-lg border border-gray-200" data-dashboard-target="widget" data-scroll-animation-target="animated">
      {/* Header */}
      <div className="mb-6">
        <h2 className="text-lg font-semibold text-gray-900 flex items-center space-x-2">
          <svg className="w-5 h-5 text-blue-600" fill="currentColor" viewBox="0 0 20 20" aria-hidden="true">
            <path fillRule="evenodd" d="M5 9V7a5 5 0 0110 0v2a2 2 0 012 2v5a2 2 0 01-2 2H5a2 2 0 01-2-2v-5a2 2 0 012-2zm8-2v2H7V7a3 3 0 016 0z" clipRule="evenodd" />
          </svg>
          <span>Account Security</span>
        </h2>
      </div>

      {/* Security Checklist */}
      <div className="space-y-3" role="list" aria-label="Security checklist">
        <SecurityItem
          type="email_verified"
          user={user}
          icon={emailIcon}
          text="Email verified"
        />
        <SecurityItem
          type="two_factor_enabled"
          user={user}
          icon={twoFactorIcon}
          text="2FA enabled"
        />
        <SecurityItem
          type="strong_password"
          user={user}
          icon={passwordIcon}
          text="Strong password"
        />
      </div>
    </div>
  );
});

export default AccountSecurityWidget;