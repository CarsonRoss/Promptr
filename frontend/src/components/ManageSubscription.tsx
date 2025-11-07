import React, { useEffect, useState } from 'react';
import { Calendar, Mail, AlertCircle } from 'lucide-react';
import { getSession, getSubscriptionStatus, cancelSubscription, reactivateSubscription, createCheckout, type SubscriptionStatus } from '../lib/api';

export default function ManageSubscription() {
  const [showCancelDialog, setShowCancelDialog] = useState(false);
  const [isCancelled, setIsCancelled] = useState(false);
  const [userEmail, setUserEmail] = useState('');
  const [renewalDate, setRenewalDate] = useState<string>('');
  const [renewalIso, setRenewalIso] = useState<string>('');
  const [isActive, setIsActive] = useState<boolean>(false);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let mounted = true;

    // 1) Instant hydrate from prefetch cache
    try {
      const cached = sessionStorage.getItem('ctx_sub_status');
      if (cached) {
        const st: SubscriptionStatus = JSON.parse(cached);
        if (mounted) {
          setRenewalIso(st.current_period_end);
          setRenewalDate(new Date(st.current_period_end).toLocaleDateString());
          setIsCancelled(!!st.cancel_at_period_end);
          setIsActive(!!st.active);
        }
      }
    } catch {}

    try {
        const cachedSess = sessionStorage.getItem('ctx_session');
        if (cachedSess) {
            const s = JSON.parse(cachedSess);
            if (mounted) setUserEmail(s.user?.email || '');
        }
    } catch {}

    // 2) Refresh in parallel
    (async () => {
      try {
        const [sess, status] = await Promise.all([
          getSession(),
          getSubscriptionStatus(),
        ]);
        if (mounted) {
          setUserEmail(sess.user?.email || '');
          setRenewalIso(status.current_period_end);
          setRenewalDate(new Date(status.current_period_end).toLocaleDateString());
          setIsCancelled(!!status.cancel_at_period_end);
          setIsActive(!!status.active);
        }
      } catch (e) {
        if (mounted) setError('Failed to load subscription details');
        console.error(e);
      } finally {
        if (mounted) setLoading(false);
      }
    })();

    return () => { mounted = false; };
  }, []);

  const handleCancel = async () => {
    try {
      const res = await cancelSubscription()
      setIsCancelled(true)
      setRenewalDate(new Date(res.access_until).toLocaleDateString())
      setRenewalIso(res.access_until)
      setShowCancelDialog(false)
    } catch (e) {
      setError('Failed to cancel subscription. Please try again.')
      console.error(e)
    }
  };

  return (
    <div className="min-h-screen w-screen bg-gray-50 flex items-center justify-center p-4">
        {/* Back button - positioned in top-left corner */}
        <button
            onClick={() => window.location.hash = '#/'}
            className="absolute top-4 left-4 text-sm text-gray-600 hover:text-gray-900 flex items-center gap-1"
        >
            ← Back
        </button>
      <div className="bg-white rounded-lg shadow-md max-w-md w-full p-8">
        <h2 className="text-2xl font-bold text-gray-900 mb-6">
          Manage Subscription
        </h2>

        {isCancelled && isActive && (
          <div className="mb-6 p-4 bg-yellow-50 border border-yellow-200 rounded-lg flex items-start gap-3">
            <div className="text-sm text-yellow-800">
              Your subscription has been cancelled. You'll retain access until {renewalDate}.
            </div>
          </div>
        )}

        <div className="space-y-6">
          {/* Email Section */}
          <div className="flex items-start gap-3">
            <Mail className="text-gray-400 flex-shrink-0 mt-1" size={20} />
            <div>
              <div className="text-sm font-medium text-gray-500 mb-1">
                Email Address
              </div>
              <div className="text-gray-900">{userEmail}</div>
            </div>
          </div>

          {/* Renewal Date Section */}
          <div className="flex items-start gap-3">
            <Calendar className="text-gray-400 flex-shrink-0 mt-1" size={20} />
            <div>
              <div className="text-sm font-medium text-gray-500 mb-1">
                {isCancelled ? 'Access Until' : 'Next Renewal'}
              </div>
              <div className="text-gray-900">{renewalDate}</div>
            </div>
          </div>

          {/* Cancel Button */}
          {!isCancelled && isActive && (
            <button
              onClick={() => setShowCancelDialog(true)}
              className="w-full mt-8 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors font-medium"
            >
              Cancel Subscription
            </button>
          )}

          {isCancelled && isActive && (
            <button
              onClick={async () => {
                try {
                  const res = await reactivateSubscription()
                  setIsCancelled(false)
                  setRenewalIso(res.access_until)
                  setRenewalDate(new Date(res.access_until).toLocaleDateString())
                } catch (e) {
                  setError('Failed to reactivate subscription. Please try again.')
                  console.error(e)
                }
              }}
              className="px-8 py-2 bg-gradient-to-r from-blue-500 to-blue-600 text-white rounded-full font-semibold text-lg shadow-lg hover:shadow-xl border-0 w-full mt-4"
            >
              Reactivate Subscription
            </button>
          )}

          {!isActive && (
            <button
              className="w-full mt-8 px-4 py-2 bg-blue-600 text-white font-semibold rounded-full border-2 border-blue-600 hover:bg-blue-700 transition-all duration-200 shadow-md hover:shadow-lg"
              onClick={async () => {
                try {
                  const { url } = await createCheckout()
                  if (!url) throw new Error('Missing checkout URL')
                  window.location.href = url
                } catch (e) {
                  setError('Upgrade failed. Please try again.')
                  console.error('Upgrade error:', e)
                }
              }}
            >
              Upgrade Now
            </button>
          )}
        </div>

        {/* Confirmation Dialog */}
        {showCancelDialog && (
          <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
            <div className="bg-white rounded-lg max-w-sm w-full p-6">
              <h2 className="text-xl font-bold text-gray-900 mb-3">
                Cancel Subscription?
              </h2>
              <p className="text-gray-600 mb-6">
                Are you sure you want to cancel your subscription? You'll continue to have access until {renewalDate}.
              </p>
              <div className="flex gap-3">
                <button
                  onClick={() => setShowCancelDialog(false)}
                  className="flex-1 px-4 py-2 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors font-medium"
                >
                  Go Back
                </button>
                <button
                  onClick={handleCancel}
                  className="flex-1 px-4 py-2 text-red-600 font-medium rounded-lg"
                >
                  Cancel
                </button>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}