import React from 'react';

// Type definitions for TypeScript
interface User {
  name: string;
}

interface DashboardHeaderProps {
  current_user: User;
}

// Presentation component
const DashboardHeader: React.FC<DashboardHeaderProps> = React.memo(({ current_user }) => {
  const greetingName = current_user.name || 'User';

  return (
    <div className="bg-gradient-to-r from-purple-600 to-pink-600 text-white p-6 rounded-xl shadow-lg">
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-2xl font-bold mb-2">Welcome back, {greetingName}! 👋</h1>
          <p className="text-purple-100">Here's what's happening with your account today</p>
        </div>

        <div className="flex space-x-4">
          <button className="bg-white text-purple-600 px-4 py-2 rounded-lg hover:bg-gray-100 transition-colors">
            <svg className="w-5 h-5 mr-2 inline" fill="currentColor" viewBox="0 0 20 20">
              <path fillRule="evenodd" d="M3 17a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1zm3.293-7.707a1 1 0 011.414 0L9 10.586V3a1 1 0 112 0v7.586l1.293-1.293a1 1 0 111.414 1.414l-3 3a1 1 0 01-1.414 0l-3-3a1 1 0 010-1.414z" clipRule="evenodd" />
            </svg>
            Export Data
          </button>

          <a href={`/users/${current_user.id}/edit`} className="bg-purple-700 text-white px-4 py-2 rounded-lg hover:bg-purple-800 transition-colors">
            <svg className="w-5 h-5 mr-2 inline" fill="currentColor" viewBox="0 0 20 20">
              <path fillRule="evenodd" d="M11.3 1.046A1 1 0 0112 2v5h4a1 1 0 01.82 1.573l-7 10A1 1 0 018 18v-5H4a1 1 0 01-.82-1.573l7-10a1 1 0 011.12-.38z" clipRule="evenodd" />
            </svg>
            Settings
          </a>
        </div>
      </div>
    </div>
  );
});

export default DashboardHeader;