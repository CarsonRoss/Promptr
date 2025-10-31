import { useState } from 'react';
import { User } from 'lucide-react';

export default function UserProfileDropdown({ userEmail, embedded = false }: { userEmail: string; embedded?: boolean }) {
  const [isOpen, setIsOpen] = useState(false);

  return (
    <div className={`${embedded ? '' : 'flex items-start justify-end min-h-screen bg-gray-50 p-8'}`}>
      <div className="relative">
        {/* Expandable Button */}
        <div
          onClick={() => setIsOpen(!isOpen)}
          className={`bg-white rounded-lg shadow-lg border border-gray-200 cursor-pointer transition-all duration-300 ${
            isOpen ? 'w-72 h-40' : 'w-12 h-12'
          }`}
        >
          <div className={`transition-opacity duration-200 ${isOpen ? 'opacity-100 delay-150' : 'opacity-0'}`}>
            {isOpen && (
              <div className="p-4">
                {/* User Info Section */}
                <div className="flex items-center gap-3 pb-4 border-b border-gray-100">
                  <div className="w-10 h-10 bg-gray-100 rounded-full flex items-center justify-center flex-shrink-0">
                    <User className="w-5 h-5 text-gray-600" />
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-sm text-gray-700 truncate font-medium">
                      {userEmail}
                    </p>
                  </div>
                </div>

                {/* Manage Subscription Button */}
                <div className="pt-4">
                  <button className="w-full px-4 py-2.5 bg-blue-600 text-white font-semibold rounded-lg hover:bg-blue-700 transition-all duration-200 shadow-sm hover:shadow-md">
                    Manage Subscription
                  </button>
                </div>
              </div>
            )}
          </div>
          
          {!isOpen && (
            <div className="w-12 h-12 flex items-center justify-center ">
              <User className="w-6 h-6 text-gray-700" />
            </div>
          )}
        </div>
      </div>
    </div>
  );
}